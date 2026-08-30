import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import '@som/ui-kit/kit.css'
import './app.css'
import { App } from './App'

// Browser mock, for `npm run dev`. `import.meta.env.DEV` is a compile-time
// constant, so the production bundle drops both the import and the file behind
// it rather than shipping a fake inventory nobody can reach.
if (import.meta.env.DEV) import('./dev')

const root = document.getElementById('root')
if (root) createRoot(root).render(<StrictMode><App /></StrictMode>)
