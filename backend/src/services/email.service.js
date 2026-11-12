
import nodemailer from 'nodemailer';
import { env } from '../config/config.js';

function smtpConfigurado() {
  return Boolean(
    process.env.SMTP_HOST &&
    process.env.SMTP_USER &&
    process.env.SMTP_PASSWORD &&
    process.env.SMTP_FROM &&
    Number(process.env.SMTP_PORT)
  );
}

function crearTransporte() {
  const puerto = Number(process.env.SMTP_PORT);

  if (
    !process.env.SMTP_HOST ||
    !process.env.SMTP_USER ||
    !process.env.SMTP_PASSWORD ||
    !process.env.SMTP_FROM ||
    !puerto
  ) {
    throw new Error('Servicio SMTP no configurado');
  }

  return nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: puerto,
    secure: process.env.SMTP_SECURE === 'true',
    requireTLS: puerto === 587,
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASSWORD,
    },
    connectionTimeout: 10000,
    greetingTimeout: 10000,
    socketTimeout: 15000,
  });
}

export async function enviarCorreo({
  destinatario,
  asunto,
  contenido,
}) {
  if (!smtpConfigurado()) {
    if (env.NODE_ENV !== 'production' && env.DEV_EMAIL_MODE === 'log') {
      console.info('[PetID correo de desarrollo]', {
        destinatario,
        asunto,
        contenido,
      });
      return;
    }

    throw new Error('Servicio SMTP no configurado');
  }

  const transporte = crearTransporte();

  await transporte.sendMail({
    from: process.env.SMTP_FROM,
    to: destinatario,
    subject: asunto,
    text: contenido,
  });
}
