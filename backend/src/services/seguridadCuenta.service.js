
import bcrypt from 'bcryptjs';

import { Usuario, TokenSeguridad } from '../models/index.js';
import { enviarCorreo } from './email.service.js';
import {
  emitirToken,
  consumirToken,
} from './tokenSeguridad.service.js';

const MENSAJE_GENERICO =
  'Si la cuenta existe, recibirás un correo con instrucciones.';

function crearEnlace(ruta, token) {
  const url = new URL(ruta, process.env.FRONTEND_ORIGIN);

  // El fragmento no se envía al servidor web.
  // React deberá leerlo y enviar el token por POST.
  url.hash = `token=${encodeURIComponent(token)}`;

  return url.toString();
}

export async function solicitarVerificacion(correo) {
  const usuario = await Usuario.findOne({
    where: { correo },
  });

  if (usuario && usuario.activo && !usuario.correo_verificado) {
    const token = await emitirToken(
      usuario.id_usuario,
      'verificacion'
    );

    await enviarCorreo({
      destinatario: usuario.correo,
      asunto: 'Verificá tu correo de PetID',
      contenido:
        'Para verificar tu correo, abrí este enlace:\n\n' +
        crearEnlace('/verificar-correo', token) +
        '\n\nEl enlace vence en 24 horas.',
    });
  }

  return MENSAJE_GENERICO;
}

export async function verificarCorreo(token) {
  await consumirToken(
    token,
    'verificacion',
    async (idUsuario, transaction) => {
      await Usuario.update(
        { correo_verificado: true },
        {
          where: {
            id_usuario: idUsuario,
            activo: true,
          },
          transaction,
        }
      );
    }
  );
}

export async function solicitarRecuperacion(correo) {
  const usuario = await Usuario.findOne({
    where: { correo },
  });

  if (usuario && usuario.activo) {
    const token = await emitirToken(
      usuario.id_usuario,
      'recuperacion'
    );

    await enviarCorreo({
      destinatario: usuario.correo,
      asunto: 'Recuperación de contraseña de PetID',
      contenido:
        'Recibimos una solicitud para cambiar tu contraseña.\n\n' +
        crearEnlace('/restablecer-contrasena', token) +
        '\n\nEl enlace vence en 15 minutos.' +
        '\nSi no fuiste vos, ignorá este correo.',
    });
  }

  return MENSAJE_GENERICO;
}

export async function restablecerContrasena(
  token,
  nuevaPassword
) {
  const password_hash = await bcrypt.hash(
    nuevaPassword,
    12
  );

  await consumirToken(
    token,
    'recuperacion',
    async (idUsuario, transaction) => {
      const usuario = await Usuario.findByPk(
        idUsuario,
        { transaction }
      );

      if (!usuario || !usuario.activo) {
        throw new Error('Cuenta no disponible');
      }

      await usuario.update(
        { password_hash },
        { transaction }
      );

      // Invalidar JWT emitidos anteriormente.
      await usuario.increment(
        'token_version',
        { transaction }
      );

      // Invalidar cualquier otro token pendiente.
      await TokenSeguridad.update(
        { fecha_consumo: new Date() },
        {
          where: {
            id_usuario: idUsuario,
            fecha_consumo: null,
          },
          transaction,
        }
      );
    }
  );
}
