# frozen_string_literal: true

class ApiDocsController < ActionController::Base
  # GET /api-docs
  # Renderiza o Swagger UI moderno com tema escuro/claro interativo
  def index
    html = <<~HTML
      <!DOCTYPE html>
      <html lang="pt-BR">
      <head>
        <meta charset="UTF-8">
        <title>DOC Intelligence API - Swagger UI</title>
        <link rel="stylesheet" type="text/css" href="https://unpkg.com/swagger-ui-dist@5.18.2/swagger-ui.css" />
        <link rel="icon" type="image/png" href="https://unpkg.com/swagger-ui-dist@5.18.2/favicon-32x32.png" sizes="32x32" />
        <style>
          html { box-sizing: border-box; overflow: -moz-scrollbars-vertical; overflow-y: scroll; }
          *, *:before, *:after { box-sizing: inherit; }
          body { margin: 0; background: #fafafa; font-family: sans-serif; }
          .topbar { display: none !important; }
        </style>
      </head>
      <body>
        <div id="swagger-ui"></div>
        <script src="https://unpkg.com/swagger-ui-dist@5.18.2/swagger-ui-bundle.js" charset="UTF-8"></script>
        <script src="https://unpkg.com/swagger-ui-dist@5.18.2/swagger-ui-standalone-preset.js" charset="UTF-8"></script>
        <script>
          window.onload = function() {
            window.ui = SwaggerUIBundle({
              url: "/swagger.json",
              dom_id: '#swagger-ui',
              deepLinking: true,
              presets: [
                SwaggerUIBundle.presets.apis,
                SwaggerUIStandalonePreset
              ],
              plugins: [
                SwaggerUIBundle.plugins.DownloadUrl
              ],
              layout: "BaseLayout",
              defaultModelsExpandDepth: 1,
              defaultModelExpandDepth: 1,
              docExpansion: "list",
              filter: true,
              showExtensions: true,
              showCommonExtensions: true,
              persistAuthorization: true
            });
          };
        </script>
      </body>
      </html>
    HTML

    render html: html.html_safe, content_type: "text/html"
  end

  # GET /swagger.json
  def swagger_json
    swagger_file = Rails.root.join("public", "swagger.json")
    if File.exist?(swagger_file)
      render json: File.read(swagger_file), content_type: "application/json"
    else
      render json: { error: "Swagger spec not found" }, status: :not_found
    end
  end
end
