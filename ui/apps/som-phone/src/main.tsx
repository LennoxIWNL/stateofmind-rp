import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './phone.css'
import { Shell } from './Shell'

const root = document.getElementById('root')
if (root) createRoot(root).render(<StrictMode><Shell /></StrictMode>)
