import type { Config } from 'tailwindcss'

const config: Config = {
  content: [
    './src/pages/**/*.{js,ts,jsx,tsx,mdx}',
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        brand: {
          parchment: '#f5f4ed',
          ivory: '#faf9f5',
          white: '#ffffff',
          sand: '#e8e6dc',
          terracotta: '#c96442',
          coral: '#d97757',
          nearBlack: '#141413',
          darkSurface: '#30302e',
          deepDark: '#141413',
          charcoalWarm: '#4d4c48',
          oliveGray: '#5e5d59',
          stoneGray: '#87867f',
          darkWarm: '#3d3d3a',
          warmSilver: '#b0aea5',
          borderCream: '#f0eee6',
          borderWarm: '#e8e6dc',
          borderDark: '#30302e',
          ringWarm: '#d1cfc5',
          errorCrimson: '#b53333',
          focusBlue: '#3898ec',
        },
      },
      fontFamily: {
        serif: ['Georgia', 'serif'],
        sans: ['system-ui', 'Inter', 'Arial', 'sans-serif'],
        mono: ['ui-monospace', 'Courier New', 'monospace'],
      },
      borderRadius: {
        sharp: '4px',
        sm: '6px',
        DEFAULT: '8px',
        md: '12px',
        lg: '16px',
        xl: '24px',
        '2xl': '32px',
      },
    },
  },
  plugins: [],
}
export default config
