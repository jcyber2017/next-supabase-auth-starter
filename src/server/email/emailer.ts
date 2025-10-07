'use server';
import nodemailer from 'nodemailer';

import isEmailValid from 'src/functions/isEmailValid';

const sendEmail = async (to: string, subject: string, text: string, html: string) => {
  'use server';
  if (!isEmailValid(to)) throw new Error('Invalid email');
  const transporter = nodemailer.createTransport({
    host: 'smtp.gmail.com',
    port: 587,
    secure: false,
    auth: {
      user: 'email@gmail.com',
      pass: 'password'
    },
  });
  await transporter.sendMail({from: '"contact" <email@gmail.com>', to, subject, text, html});
};

export default sendEmail;
