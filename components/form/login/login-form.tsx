/**
 * Ferretería - Gestión de Pedidos
 * Copyright (c) 2025 Juan Villegas <juancvillefer@gmail.com>
 * Apache 2.0 Licensed
 */

"use client"

import type React from "react"

import { useState } from "react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { useAuth } from "@/hooks/use-auth"
import type { LoginCredentials } from "@/types"
import { notificationService } from "@/services/notification.service"

interface LoginFormProps {
  onSuccess?: () => void
}

export function LoginForm({ onSuccess }: LoginFormProps) {
  const [credentials, setCredentials] = useState<LoginCredentials>({
    email: "",
    password: "",
  })
  const [error, setError] = useState("")
  const { login, loading } = useAuth()

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError("")

    if (!credentials.email || !credentials.password) {
      const errorMsg = "Por favor complete todos los campos"
      setError(errorMsg)
      notificationService.error("Campos incompletos", errorMsg)
      return
    }

    try {
      const success = await login(credentials)
      if (success) {
        notificationService.success(
          "Inicio de sesión exitoso",
          "Bienvenido al sistema Ferreteria"
        )
        onSuccess?.()
      } else {
        const errorMsg = "Credenciales incorrectas"
        setError(errorMsg)
        notificationService.error(
          "Error de autenticación",
          "El correo o la contraseña son incorrectos. Por favor, verifica tus credenciales."
        )
      }
    } catch (error: any) {
      const errorMsg = error?.message || "Error al iniciar sesión"
      setError(errorMsg)
      notificationService.error(
        "Error al iniciar sesión",
        "Ocurrió un problema al intentar iniciar sesión. Por favor, intenta nuevamente."
      )
      console.error("Login error:", error)
    }
  }

  return (
    <Card className="w-full max-w-md mx-auto">
      <CardHeader className="text-center">
        <div className="flex items-center justify-center gap-2 mb-4">
          <img src="/logo.jpg" alt="Ferreteria" className="h-10 md:h-12 w-auto" />
        </div>
        <CardDescription>Ingresa tus credenciales para acceder al sistema</CardDescription>
      </CardHeader>
      <CardContent>
        <div className="mb-4 rounded-md border border-amber-300 bg-amber-50 px-3 py-2.5 text-sm text-amber-900">
          <p className="font-medium">Demo — usa estas credenciales de administrador de prueba para ingresar:</p>
          <p className="mt-1 font-mono text-xs">admin@ferreteria.com &nbsp;/&nbsp; admin123</p>
          <button
            type="button"
            onClick={() => setCredentials({ email: "admin@ferreteria.com", password: "admin123" })}
            className="mt-2 text-xs font-medium text-amber-800 underline underline-offset-2 hover:text-amber-950"
          >
            Rellenar automáticamente
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="email">Correo electrónico</Label>
            <Input
              id="email"
              type="email"
              value={credentials.email}
              onChange={(e) => setCredentials((prev) => ({ ...prev, email: e.target.value }))}
              placeholder="usuario@Ferreteria.com"
              disabled={loading}
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="password">Contraseña</Label>
            <Input
              id="password"
              type="password"
              value={credentials.password}
              onChange={(e) => setCredentials((prev) => ({ ...prev, password: e.target.value }))}
              placeholder="••••••••"
              disabled={loading}
            />
          </div>

          <Button type="submit" className="w-full" disabled={loading}>
            {loading ? "Ingresando..." : "Ingresar"}
          </Button>
        </form>
      </CardContent>
    </Card>
  )
}
