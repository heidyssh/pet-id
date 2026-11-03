
export function validar(schema) {
  return (req, res, next) => {
    const resultado = schema.safeParse(req.body);

    if (!resultado.success) {
      return res.status(400).json({
        success: false,
        message: 'Datos de entrada inválidos',
        errors: resultado.error.issues.map((issue) => ({
          campo: issue.path.join('.') || 'body',
          mensaje: issue.message,
        })),
      });
    }

    req.body = resultado.data;
    return next();
  };
}
