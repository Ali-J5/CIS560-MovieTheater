// Mount the application; StrictMode also checks effect cleanup during development.
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import App from './App.jsx';
import './App.css';

createRoot(document.getElementById('root')).render(
  <StrictMode><App /></StrictMode>,
);
