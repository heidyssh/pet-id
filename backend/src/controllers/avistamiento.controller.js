
import {
  crearAvistamiento,
  listarAvistamientos,
  listarMisAvistamientos,
  obtenerAvistamiento,
} from '../services/avistamiento.service.js';

import {
  listarAvistamientosSchema,
} from '../schemas/avistamiento.schema.js';

import { AppError } from '../utils/AppError.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import {
  crearAvistamientoSchema,
  escanearAvistamientoSchema,
} from '../schemas/avistamiento.schema.js';
import { agregarFotoAvistamiento } from '../services/foto.service.js';
import { Avistamiento } from '../models/index.js';
import {
  generarCoincidencias,
  generarCoincidenciasVisuales,
} from '../services/coincidencia.service.js';

function obtenerFiltros(query) {
  const resultado = listarAvistamientosSchema.safeParse(
    query
  );

  if (!resultado.success) {
    throw new AppError(
      'Parámetros de búsqueda inválidos',
      400
    );
  }

  return resultado.data;
}

function mensajeValidacion(resultado, fallback) {
  return resultado.error?.issues?.[0]?.message ?? fallback;
}

// Avistamiento anónimo
export const registrarAnonimo = asyncHandler(
  async (req, res) => {
    const avistamiento = await crearAvistamiento(
      req.body,
      null
    );

    return res.status(201).json({
      success: true,
      message: 'Avistamiento registrado correctamente',
      data: avistamiento,
    });
  }
);

export const registrarAnonimoConFoto = asyncHandler(
  async (req, res) => {
    if (!req.file) {
      throw new AppError('Debe enviar una fotografía', 400);
    }

    let datos;
    try {
      datos = JSON.parse(req.body.datos);
    } catch {
      throw new AppError('El campo datos debe contener JSON válido', 400);
    }

    const validacion = crearAvistamientoSchema.safeParse(datos);
    if (!validacion.success) {
      throw new AppError(
        mensajeValidacion(validacion, 'Datos del avistamiento inválidos'),
        400
      );
    }

    const avistamiento = await crearAvistamiento(validacion.data, null, false);

    try {
      const foto = await agregarFotoAvistamiento(
        avistamiento.id_avistamiento,
        null,
        req.file,
        req.body.tipo_captura
      );
      await generarCoincidencias(avistamiento.id_avistamiento);
      return res.status(201).json({
        success: true,
        message: 'Avistamiento anónimo registrado correctamente',
        data: { ...avistamiento, foto },
      });
    } catch (error) {
      await Avistamiento.destroy({
        where: { id_avistamiento: avistamiento.id_avistamiento, id_usuario: null },
      });
      throw error;
    }
  }
);

// Avistamiento de usuario autenticado
async function procesarEscaneo(req, res, idUsuario) {
  if (!req.file) throw new AppError('Debe enviar una fotografía', 400);

  let datos;
  try {
    datos = JSON.parse(req.body.datos);
  } catch {
    throw new AppError('El campo datos debe contener JSON válido', 400);
  }

  const validacion = escanearAvistamientoSchema.safeParse(datos);
  if (!validacion.success) {
    throw new AppError(
      mensajeValidacion(validacion, 'Datos del escaneo inválidos'),
      400
    );
  }

  const avistamiento = await crearAvistamiento(validacion.data, idUsuario, false);
  try {
    const foto = await agregarFotoAvistamiento(
      avistamiento.id_avistamiento,
      idUsuario,
      req.file,
      req.body.tipo_captura
    );

    const resultado = foto.vector_generado
      ? await generarCoincidenciasVisuales(avistamiento.id_avistamiento, foto.id_foto)
      : {
        total: await generarCoincidencias(avistamiento.id_avistamiento),
        coincidencias: [],
        procesamiento: 'sin_vector_visual',
      };

    return res.status(201).json({
      success: true,
      message: 'Escaneo de mascota procesado correctamente',
      data: { ...avistamiento, foto, resultado },
    });
  } catch (error) {
    await Avistamiento.destroy({
      where: { id_avistamiento: avistamiento.id_avistamiento, id_usuario: idUsuario },
    });
    throw error;
  }
}

export const registrarEscaneoAnonimo = asyncHandler(
  async (req, res) => procesarEscaneo(req, res, null)
);

export const registrarEscaneoAutenticado = asyncHandler(
  async (req, res) => procesarEscaneo(req, res, req.usuario.id_usuario)
);

export const registrarAutenticado = asyncHandler(
  async (req, res) => {
    const avistamiento = await crearAvistamiento(
      req.body,
      req.usuario.id_usuario
    );

    return res.status(201).json({
      success: true,
      message: 'Avistamiento registrado correctamente',
      data: avistamiento,
    });
  }
);

// Listar avistamientos públicos
export const obtenerAvistamientos = asyncHandler(
  async (req, res) => {
    const resultado = await listarAvistamientos(
      obtenerFiltros(req.query)
    );

    return res.status(200).json({
      success: true,
      data: resultado,
    });
  }
);

// Listar avistamientos del usuario
export const obtenerMisAvistamientos = asyncHandler(
  async (req, res) => {
    const resultado = await listarMisAvistamientos(
      req.usuario.id_usuario,
      obtenerFiltros(req.query)
    );

    return res.status(200).json({
      success: true,
      data: resultado,
    });
  }
);

// Detalle público
export const detalleAvistamiento = asyncHandler(
  async (req, res) => {
    const avistamiento = await obtenerAvistamiento(
      req.params.idAvistamiento
    );

    return res.status(200).json({
      success: true,
      data: avistamiento,
    });
  }
);
