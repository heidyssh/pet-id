import { QueryTypes } from 'sequelize';
import { sequelize } from '../config/sequelize.js';

function parametros(filtros) {
  return {
    latitud: filtros.latitud,
    longitud: filtros.longitud,
    metros: filtros.radio_km * 1000,
    id_especie: filtros.id_especie ?? null,
    limite: filtros.limite,
    offset: (filtros.pagina - 1) * filtros.limite,
  };
}

function empaquetar(rows, { pagina, limite }) {
  const total = Number(rows[0]?.total_resultados ?? 0);
  return {
    items: rows.map(({ total_resultados, ...item }) => item),
    paginacion: {
      pagina,
      limite,
      total,
      total_paginas: Math.ceil(total / limite),
    },
  };
}

export async function extraviosCercanos(filtros) {
  const rows = await sequelize.query(`
    SELECT
      r.id_reporte,
      r.fecha_perdida,
      r.fecha_reporte,
      r.referencia_lugar,
      r.radio_km,
      m.id_mascota,
      m.nombre AS nombre_mascota,
      m.id_especie,
      m.color_principal,
      m.tamano,
      e.nombre AS especie,
      rz.nombre AS raza,
      (
        SELECT COALESCE(f.url_recorte, f.url_original)
        FROM fotos_mascotas f
        WHERE f.id_mascota = m.id_mascota
        ORDER BY f.es_principal DESC, f.id_foto ASC
        LIMIT 1
      ) AS foto,
      ROUND((ST_Distance(
        r.ubicacion,
        ST_SetSRID(ST_MakePoint(:longitud, :latitud), 4326)::geography
      ) / 1000)::numeric, 2) AS distancia_km,
      ROUND(ST_Y(r.ubicacion::geometry)::numeric, 3) AS latitud_aproximada,
      ROUND(ST_X(r.ubicacion::geometry)::numeric, 3) AS longitud_aproximada,
      COUNT(*) OVER() AS total_resultados
    FROM reportes_extravio r
    JOIN mascotas m ON m.id_mascota = r.id_mascota
    JOIN especies e ON e.id_especie = m.id_especie
    LEFT JOIN razas rz ON rz.id_raza = m.id_raza
    WHERE r.estado = 'activo'
      AND r.ubicacion IS NOT NULL
      AND (:id_especie::smallint IS NULL OR m.id_especie = :id_especie)
      AND ST_DWithin(
        r.ubicacion,
        ST_SetSRID(ST_MakePoint(:longitud, :latitud), 4326)::geography,
        :metros
      )
    ORDER BY distancia_km ASC, r.fecha_reporte DESC
    LIMIT :limite OFFSET :offset
  `, {
    replacements: parametros(filtros),
    type: QueryTypes.SELECT,
  });

  return empaquetar(rows, filtros);
}

export async function avistamientosCercanos(filtros) {
  const rows = await sequelize.query(`
    SELECT
      a.id_avistamiento,
      a.id_especie,
      a.fecha_avistamiento,
      a.fecha_registro,
      a.referencia_lugar,
      a.color_principal,
      a.tamano,
      a.senas_particulares,
      a.descripcion,
      ROUND((ST_Distance(
        a.ubicacion,
        ST_SetSRID(ST_MakePoint(:longitud, :latitud), 4326)::geography
      ) / 1000)::numeric, 2) AS distancia_km,
      ROUND(ST_Y(a.ubicacion::geometry)::numeric, 3) AS latitud_aproximada,
      ROUND(ST_X(a.ubicacion::geometry)::numeric, 3) AS longitud_aproximada,
      COUNT(*) OVER() AS total_resultados
    FROM avistamientos a
    WHERE a.estado IN ('registrado', 'revisado')
      AND a.ubicacion IS NOT NULL
      AND (:id_especie::smallint IS NULL OR a.id_especie = :id_especie)
      AND ST_DWithin(
        a.ubicacion,
        ST_SetSRID(ST_MakePoint(:longitud, :latitud), 4326)::geography,
        :metros
      )
    ORDER BY distancia_km ASC, a.fecha_avistamiento DESC
    LIMIT :limite OFFSET :offset
  `, {
    replacements: parametros(filtros),
    type: QueryTypes.SELECT,
  });

  return empaquetar(rows, filtros);
}
