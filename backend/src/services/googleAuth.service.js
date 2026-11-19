import bcrypt from 'bcryptjs';
import { randomBytes } from 'node:crypto';
import { UniqueConstraintError } from 'sequelize';
import { z } from 'zod';
import { env } from '../config/config.js';
import { sequelize } from '../config/sequelize.js';
import { Usuario } from '../models/index.js';
import { AppError } from '../utils/AppError.js';
import { crearCiudadano, datosPublicos } from './auth.service.js';
import { crearSesionConTokens } from './sesion.service.js';

let clientePromise;
const perfilSchema = z.object({
  sub: z.string().min(1).max(255),
  email: z.email().toLowerCase().max(150),
  email_verified: z.literal(true),
  hd: z.string().optional(),
  given_name: z.string().optional(),
  family_name: z.string().optional(),
});

// Aplica la misma regla del registro: solo letras, un espacio y 30 letras.
function nombreGoogle(valor, alternativo) {
  let resultado = '';
  let letras = 0;
  let conEspacio = false;
  for (const [parte] of (valor ?? '').normalize().matchAll(/\p{L}\p{M}*|\s+/gu)) {
    if (/\p{L}/u.test(parte)) {
      if (letras === 30) break;
      resultado += parte;
      letras += 1;
    } else if (letras > 0 && !conEspacio) {
      resultado += ' ';
      conEspacio = true;
    } else if (conEspacio) {
      break;
    }
  }
  resultado = resultado.trim();
  return letras >= 2 ? resultado : alternativo;
}

async function resolverUsuario(perfil) {
  return sequelize.transaction(async (transaction) => {
    const cuentas = Usuario.scope('withGoogleIdentity');
    const opciones = { transaction, lock: transaction.LOCK.UPDATE };
    const vinculada = await cuentas.findOne({ ...opciones, where: { google_sub: perfil.sub } });
    if (vinculada) {
      if (!vinculada.activo) throw new AppError('Cuenta no disponible.', 403);
      return vinculada;
    }

    // Google puede confirmar la titularidad de Gmail y de su propio Workspace.
    if (!perfil.email.endsWith('@gmail.com') && !perfil.hd) {
      throw new AppError('Usa el acceso con correo y contraseña para esta dirección.', 403);
    }
    const existente = await cuentas.findOne({ ...opciones, where: { correo: perfil.email } });
    if (existente) {
      if (!existente.activo || !existente.correo_verificado || existente.google_sub) {
        throw new AppError('Usa el acceso con correo y contraseña para esta cuenta.', 403);
      }
      await existente.update({ google_sub: perfil.sub }, { transaction });
      return existente;
    }

    return crearCiudadano({
      nombre: nombreGoogle(perfil.given_name, 'Usuario'),
      apellido: nombreGoogle(perfil.family_name, 'PetID'),
      correo: perfil.email,
      correo_verificado: true,
      google_sub: perfil.sub,
      password_hash: await bcrypt.hash(randomBytes(32).toString('base64url'), 12),
    }, transaction);
  });
}

export async function iniciarSesionGoogle(idToken, agenteUsuario) {
  if (!env.GOOGLE_SIGN_IN_CLIENT_ID) {
    throw new AppError('El inicio de sesión con Google aún no está disponible.', 503);
  }
  clientePromise ??= import('google-auth-library').then(({ OAuth2Client }) => new OAuth2Client());
  let cliente;
  try {
    cliente = await clientePromise;
  } catch {
    clientePromise = undefined;
    throw new AppError('No se pudo conectar el servicio de Google.', 503);
  }
  let ticket;
  try {
    ticket = await cliente.verifyIdToken({
      idToken,
      audience: env.GOOGLE_SIGN_IN_CLIENT_ID,
    });
  } catch {
    throw new AppError('No se pudo verificar tu cuenta de Google.', 401);
  }
  const perfil = perfilSchema.safeParse(ticket.getPayload());
  if (!perfil.success) throw new AppError('No se pudo verificar tu cuenta de Google.', 401);

  let usuario;
  try {
    usuario = await resolverUsuario(perfil.data);
  } catch (error) {
    if (!(error instanceof UniqueConstraintError)) throw error;
    usuario = await resolverUsuario(perfil.data);
  }
  const tokens = await crearSesionConTokens(usuario, agenteUsuario);
  return { usuario: datosPublicos(usuario), ...tokens };
}
