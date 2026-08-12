/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
      colors: {
        bili: {
          blue: '#00AEEC',
          pink: '#FB7299',
          50: '#F4F4F4',
          100: '#E3E5E7',
          200: '#C9CCD0',
          300: '#A2A6AB',
          400: '#61666D',
          500: '#505357',
          600: '#36393D',
          700: '#1F2123',
          800: '#18191C',
          900: '#0F1011',
        },
      },
    },
  },
  plugins: [],
}
