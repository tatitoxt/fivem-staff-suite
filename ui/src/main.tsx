import './styles/fonts.css';
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import './styles/global.css';
import { App } from './App';
import { useMock } from './nui';

if (useMock()) document.documentElement.classList.add('dev-harness');

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
