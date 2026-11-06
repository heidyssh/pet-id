
import { sequelize } from '../config/sequelize.js';

import {
  Mascota,
  Especie,
  Raza,
  FotoMascota,
} from '../models/index.js';

import { AppError } from '../utils/AppError.js';

const atributosMascota = [
  'id_mascota',
  'id_dueno',
  'id_especie',
  'id_raza',
  'nombre',
  'sexo',
  'color_principal',
  'tamano',
  'senas_particulares',
  'fecha_nacimiento',
  'estado',
  'fecha_registro',
];

const relacionesMascota = [
  {
    model: Especie,
    as: 'especie',
    attributes: ['id_especie', 'nombre'],
  },
  {
    model: Raza,
    as: 'raza',
    attributes: ['id_raza', 'nombre'],
    required: false,
  },
  {
    model: FotoMascota,
    as: 'fotos',
    attributes: [
      'id_foto',
      'url_original',
      'url_recorte',
      'es_principal',
    ],
    required: false,
  },
];

function validarId(id) {
  if (
    typeof id !== 'string' ||
    !/^[1-9]\d{0,18}$/.test(id) ||
    BigInt(id) > 9223372036854775807n
  ) {
    throw new AppError('Identificador inválido', 400);
  }

  return id;
}

async function validarEspecieRaza(
  idEspecie,
  idRaza,
  transaction
) {
  const especie = await Especie.findByPk(idEspecie, {
    transaction,
  });

  if (!especie) {
    throw new AppError('Especie no válida', 400);
  }

  if (idRaza != null) {
    const raza = await Raza.findOne({
      where: {
        id_raza: idRaza,
        id_especie: idEspecie,
      },
      transaction,
    });

    if (!raza) {
      throw new AppError(
        'La raza no corresponde a la especie',
        400
      );
    }
  }
}

// ==========================================
// CREAR MASCOTA
// ==========================================

export async function crearMascota(
  datos,
  idUsuario
) {
  return sequelize.transaction(async (transaction) => {
    await validarEspecieRaza(
      datos.id_especie,
      datos.id_raza,
      transaction
    );

    return Mascota.create({
      ...datos,
      id_raza: datos.id_raza ?? null,
      id_dueno: idUsuario,
      estado: 'a_salvo',
    }, { transaction });
  });
}

// ==========================================
// LISTAR MASCOTAS DEL USUARIO
// ==========================================

export async function listarMisMascotas(
  idUsuario,
  { pagina, limite }
) {
  const offset = (pagina - 1) * limite;

  const { count, rows } = await Mascota.findAndCountAll({
    where: {
      id_dueno: idUsuario,
    },
    attributes: atributosMascota,
    order: [
      ['fecha_registro', 'DESC'],
      ['id_mascota', 'DESC'],
    ],
    limit: limite,
    offset,
  });

  return {
    mascotas: rows,
    paginacion: {
      pagina,
      limite,
      total: count,
      total_paginas: Math.ceil(count / limite),
    },
  };
}

// ==========================================
// OBTENER DETALLE DE UNA MASCOTA
// ==========================================

export async function obtenerMiMascota(
  idMascota,
  idUsuario
) {
  const mascota = await Mascota.findOne({
    where: {
      id_mascota: validarId(idMascota),
      id_dueno: idUsuario,
    },
    attributes: atributosMascota,
    include: relacionesMascota,
  });

  if (!mascota) {
    throw new AppError(
      'Mascota no encontrada',
      404
    );
  }

  return mascota;
}

// ==========================================
// ACTUALIZAR MASCOTA
// ==========================================

export async function actualizarMiMascota(
  idMascota,
  idUsuario,
  datos
) {
  const id = validarId(idMascota);

  await sequelize.transaction(async (transaction) => {
    const mascota = await Mascota.findOne({
      where: {
        id_mascota: id,
        id_dueno: idUsuario,
      },
      transaction,
      lock: transaction.LOCK.UPDATE,
    });

    if (!mascota) {
      throw new AppError(
        'Mascota no encontrada',
        404
      );
    }

    const especieFinal =
      datos.id_especie ?? mascota.id_especie;

    const cambioEspecie =
      datos.id_especie !== undefined &&
      String(datos.id_especie) !==
        String(mascota.id_especie);

    const razaFinal =
      datos.id_raza !== undefined
        ? datos.id_raza
        : cambioEspecie
          ? null
          : mascota.id_raza;

    await validarEspecieRaza(
      especieFinal,
      razaFinal,
      transaction
    );

    await mascota.update({
      ...datos,
      id_raza: razaFinal,
    }, { transaction });
  });

  return obtenerMiMascota(id, idUsuario);
}
