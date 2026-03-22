# searxng-local

SearXNG local para usar como backend de busqueda web con OpenClaw.

## Requisitos

- Docker y Docker Compose instalados

## Instalacion

```bash
bash install.sh
```

El script automaticamente:
- Verifica que Docker este corriendo
- Detecta si el puerto esta ocupado y busca uno libre
- Genera una secret key segura
- Levanta SearXNG + Redis

Al finalizar muestra la URL del servicio (por defecto `http://localhost:8889`).

## Configuracion del puerto

Edita `.env` para cambiar el puerto antes de ejecutar `install.sh`:

```env
SEARXNG_PORT=8889
```

## Conectar OpenClaw a SearXNG

### Opcion 1: Variable de entorno

Configura la variable `SEARXNG_URL` en tu entorno de OpenClaw:

```env
SEARXNG_URL=http://localhost:8889
```

### Opcion 2: Skill searxng-local

Instala el skill de SearXNG en OpenClaw:

```bash
openclaw plugins install ~/claw-search
```

Y configura el endpoint en `openclaw.json`:

```json
{
  "searxng": {
    "baseUrl": "http://localhost:8889",
    "timeoutMs": 10000,
    "defaultCount": 5
  }
}
```

### Verificar conexion

Prueba que SearXNG responde correctamente con la API JSON:

```bash
curl "http://localhost:8889/search?q=test&format=json"
```

Si recibes un JSON con resultados, la conexion esta lista.

## Notas

- El formato JSON ya esta habilitado en `searxng/settings.yml` (requerido por OpenClaw)
- El idioma por defecto es espanol (`es`)
- El limiter esta desactivado para uso local
- Redis (Valkey) se usa como cache
