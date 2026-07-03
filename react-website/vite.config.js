import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

const repository = process.env.GITHUB_REPOSITORY?.split('/')[1]
const isGitHubPagesBuild = process.env.GITHUB_ACTIONS === 'true'
const isUserOrOrgPage = repository?.endsWith('.github.io') ?? false
const base = process.env.VITE_BASE_PATH
  ?? (isGitHubPagesBuild && repository && !isUserOrOrgPage ? `/${repository}/` : '/')

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  base,
})
