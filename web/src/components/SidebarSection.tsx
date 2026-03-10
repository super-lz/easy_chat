import type { ReactNode } from 'react'

type SidebarSectionProps = {
  children: ReactNode
  title: string
}

export function SidebarSection({ children, title }: SidebarSectionProps) {
  return (
    <div className="sidebar-section">
      <p className="section-title">{title}</p>
      {children}
    </div>
  )
}
