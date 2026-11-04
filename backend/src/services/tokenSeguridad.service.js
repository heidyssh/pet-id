
import { randomBytes, createHash } from 'node:crypto';
import { Op } from 'sequelize';

import { sequelize } from '../config/sequelize.js';
import { TokenSeguridad } from '../models/index.js';
import { AppError } from '../utils/AppError.js';

const DURACIONES = {
  verificacion: 24 * 60 * 60 * 1000,
  recuperacion: 15 * 60 * 1000,
};

export function calcularHash(token) {
  return createHash('sha256')
    .update(token)
    .digest('hex');
}

export async function emitirToken(idUsuario, tipo) {
  if (!DURACIONES[tipo]) {
    throw new AppError('Tipo de token inválido', 500);
  }

  const token = randomBytes(32).toString('hex');
  const token_hash = calcularHash(token);

  await sequelize.transaction(async (transaction) => {
    await TokenSeguridad.update(
      { fecha_consumo: new Date() },
      {
        where: {
          id_usuario: idUsuario,
          tipo,
          fecha_consumo: null,
        },
        transaction,
      }
    );

    await TokenSeguridad.create({
      id_usuario: idUsuario,
      tipo,
      token_hash,
      fecha_expiracion: new Date(
        Date.now() + DURACIONES[tipo]
      ),
    }, { transaction });
  });

  return token;
}

export async function consumirToken(
  token,
  tipo,
  operacion
) {
  if (!/^[a-f0-9]{64}$/.test(token)) {
    throw new AppError('Enlace inválido o expirado', 400);
  }

  return sequelize.transaction(async (transaction) => {
    const registro = await TokenSeguridad.findOne({
      where: {
        token_hash: calcularHash(token),
        tipo,
        fecha_consumo: null,
        fecha_expiracion: {
          [Op.gt]: new Date(),
        },
      },
      transaction,
      lock: transaction.LOCK.UPDATE,
    });

    if (!registro) {
      throw new AppError(
        'Enlace inválido o expirado',
        400
      );
    }

    await operacion(registro.id_usuario, transaction);

    await registro.update({
      fecha_consumo: new Date(),
    }, { transaction });

    return true;
  });
}
