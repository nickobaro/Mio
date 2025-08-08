
#!/bin/bash  
  
# Script de Instalación Automática de Izing en Ubuntu  
# Versión: 1.0  
# Compatible con Ubuntu 18.04, 20.04, 22.04  
  
set -e  
  
# Colores para output  
RED='\033[0;31m'  
GREEN='\033[0;32m'  
YELLOW='\033[1;33m'  
BLUE='\033[0;34m'  
NC='\033[0m' # No Color  
  
# Función para mostrar mensajes  
print_status() {  
    echo -e "${GREEN}[INFO]${NC} $1"  
}  
  
print_error() {  
    echo -e "${RED}[ERROR]${NC} $1"  
}  
  
print_warning() {  
    echo -e "${YELLOW}[WARNING]${NC} $1"  
}  
  
print_question() {  
    echo -e "${BLUE}[PREGUNTA]${NC} $1"  
}  
  
# Verificar si se ejecuta como root  
check_root() {  
    if [[ $EUID -eq 0 ]]; then  
        print_error "No ejecutes este script como root. Usa un usuario regular con privilegios sudo."  
        exit 1  
    fi  
}  
  
# Instalar dependencias del sistema  
install_system_dependencies() {  
    print_status "Actualizando repositorios del sistema..."  
    sudo apt update  
  
    print_status "Instalando dependencias del sistema..."  
      
    # Instalar curl, wget, gnupg  
    sudo apt install -y curl wget gnupg2 software-properties-common apt-transport-https ca-certificates  
  
    # Instalar Node.js 18  
    print_status "Instalando Node.js 18..."  
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -  
    sudo apt install -y nodejs  
  
    # Instalar PostgreSQL  
    print_status "Instalando PostgreSQL..."  
    sudo apt install -y postgresql postgresql-contrib  
  
    # Instalar Redis  
    print_status "Instalando Redis..."  
    sudo apt install -y redis-server  
  
    # Instalar ffmpeg  
    print_status "Instalando ffmpeg..."  
    sudo apt install -y ffmpeg  
  
    # Instalar Google Chrome  
    print_status "Instalando Google Chrome..."  
    wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -  
    echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list  
    sudo apt update  
    sudo apt install -y google-chrome-stable  
  
    # Instalar fuentes adicionales  
    print_status "Instalando fuentes adicionales..."  
    sudo apt install -y fonts-liberation fonts-ipafont-gothic fonts-wqy-zenhei fonts-thai-tlwg fonts-kacst fonts-freefont-ttf  
  
    # Instalar PM2 globalmente  
    print_status "Instalando PM2..."  
    sudo npm install -g pm2 yarn  
  
    # Instalar Sequelize CLI  
    sudo npm install -g sequelize-cli  
}  
  
# Configurar PostgreSQL  
setup_postgresql() {  
    print_status "Configurando PostgreSQL..."  
      
    # Iniciar y habilitar PostgreSQL  
    sudo systemctl start postgresql  
    sudo systemctl enable postgresql  
  
    # Solicitar credenciales de base de datos  
    print_question "Configuración de la base de datos PostgreSQL:"  
      
    read -p "Nombre de la base de datos [izing]: " DB_NAME  
    DB_NAME=${DB_NAME:-izing}  
      
    read -p "Usuario de PostgreSQL [postgres]: " DB_USER  
    DB_USER=${DB_USER:-postgres}  
      
    read -s -p "Contraseña para el usuario PostgreSQL: " DB_PASS  
    echo  
      
    read -p "Host de PostgreSQL [localhost]: " DB_HOST  
    DB_HOST=${DB_HOST:-localhost}  
      
    read -p "Puerto de PostgreSQL [5432]: " DB_PORT  
    DB_PORT=${DB_PORT:-5432}  
  
    # Crear base de datos y usuario  
    sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"  
    sudo -u postgres psql -c "CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASS';"  
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"  
    sudo -u postgres psql -c "ALTER USER $DB_USER CREATEDB;"  
  
    print_status "PostgreSQL configurado exitosamente."  
}  
  
# Configurar Redis  
setup_redis() {  
    print_status "Configurando Redis..."  
      
    # Iniciar y habilitar Redis  
    sudo systemctl start redis-server  
    sudo systemctl enable redis-server  
      
    # Configurar Redis para escuchar en todas las interfaces (opcional)  
    sudo sed -i 's/^bind 127.0.0.1/bind 127.0.0.1/' /etc/redis/redis.conf  
    sudo systemctl restart redis-server  
      
    print_status "Redis configurado exitosamente."  
}  
  
# Solicitar configuraciones de la aplicación  
get_app_configuration() {  
    print_question "Configuración de la aplicación Izing:"  
      
    read -p "URL del Backend (ej: http://localhost o http://tu-dominio.com) [http://localhost]: " BACKEND_URL  
    BACKEND_URL=${BACKEND_URL:-http://localhost}  
      
    read -p "URL del Frontend (ej: http://localhost:3003 o http://tu-dominio.com:3003) [http://localhost:3003]: " FRONTEND_URL  
    FRONTEND_URL=${FRONTEND_URL:-http://localhost:3003}  
      
    read -p "Puerto del Backend [3000]: " BACKEND_PORT  
    BACKEND_PORT=${BACKEND_PORT:-3000}  
      
    read -p "Puerto del Proxy [3100]: " PROXY_PORT  
    PROXY_PORT=${PROXY_PORT:-3100}  
      
    read -p "Puerto de Redis [6379]: " REDIS_PORT  
    REDIS_PORT=${REDIS_PORT:-6379}  
      
    # Generar JWT secrets aleatorios  
    JWT_SECRET=$(openssl rand -base64 64 | tr -d "=+/" | cut -c1-32)  
    JWT_REFRESH_SECRET=$(openssl rand -base64 64 | tr -d "=+/" | cut -c1-32)  
      
    print_status "Configuraciones recibidas."  
}  
  
# Clonar e instalar la aplicación  
install_application() {  
    print_status "Clonando el repositorio de Izing..."  
      
    # Crear directorio de instalación  
    INSTALL_DIR="/opt/izing"  
    sudo mkdir -p $INSTALL_DIR  
    sudo chown $USER:$USER $INSTALL_DIR  
      
    # Clonar repositorio  
    git clone https://github.com/nickobaro/izing-nb.git $INSTALL_DIR  
    cd $INSTALL_DIR  
  
    # Instalar dependencias del backend  
    print_status "Instalando dependencias del backend..."  
    cd backend  
    npm install  
  
    # Crear archivo .env del backend  
    print_status "Configurando archivo .env del backend..."  
    cat > .env << EOF  
NODE_ENV=production  
BACKEND_URL=$BACKEND_URL  
FRONTEND_URL=$FRONTEND_URL  
PROXY_PORT=$PROXY_PORT  
PORT=$BACKEND_PORT  
  
# Base de datos  
DB_DIALECT=postgres  
DB_PORT=$DB_PORT  
POSTGRES_HOST=$DB_HOST  
POSTGRES_USER=$DB_USER  
POSTGRES_PASSWORD=$DB_PASS  
POSTGRES_DB=$DB_NAME  
  
# JWT  
JWT_SECRET=$JWT_SECRET  
JWT_REFRESH_SECRET=$JWT_REFRESH_SECRET  
  
# Redis  
IO_REDIS_SERVER=localhost  
IO_REDIS_PORT='$REDIS_PORT'  
IO_REDIS_DB_SESSION='2'  
  
# Chrome  
CHROME_BIN=/usr/bin/google-chrome-stable  
  
# Configuraciones de tiempo  
MIN_SLEEP_BUSINESS_HOURS=10000  
MAX_SLEEP_BUSINESS_HOURS=20000  
MIN_SLEEP_AUTO_REPLY=4000  
MAX_SLEEP_AUTO_REPLY=6000  
MIN_SLEEP_INTERVAL=2000  
MAX_SLEEP_INTERVAL=5000  
  
# Admin  
ADMIN_DOMAIN=izing.io  
EOF  
  
    # Compilar backend  
    print_status "Compilando backend..."  
    npm run build  
  
    # Ejecutar migraciones  
    print_status "Ejecutando migraciones de base de datos..."  
    npm run db:migrate  
  
    # Ejecutar seeds (datos iniciales)  
    print_status "Insertando datos iniciales..."  
    npm run db:seed  
  
    # Instalar frontend  
    print_status "Instalando dependencias del frontend..."  
    cd ../frontend  
    npm install  
  
    # Configurar frontend (si tiene archivo de configuración)  
    print_status "Configurando frontend..."  
      
    # Crear archivo de configuración de API para el frontend  
    cat > src/boot/axios.js << EOF  
import axios from 'axios'  
  
const api = axios.create({  
  baseURL: '$BACKEND_URL:$PROXY_PORT'  
})  
  
export default ({ Vue }) => {  
  Vue.prototype.\$http = api  
}  
  
export { api }  
EOF  
  
    # Compilar frontend para producción  
    print_status "Compilando frontend..."  
    npm run build  
}  
  
# Configurar servicios con PM2  
setup_services() {  
    print_status "Configurando servicios con PM2..."  
      
    cd $INSTALL_DIR/backend  
      
    # Crear archivo ecosystem.config.js personalizado  
    cat > ecosystem.config.js << EOF  
module.exports = {  
  apps: [  
    {  
      name: 'izing-backend',  
      script: './dist/server.js',  
      instances: 1,  
      exec_mode: 'fork',  
      env: {  
        NODE_ENV: 'production',  
        PORT: $BACKEND_PORT  
      },  
      error_file: './logs/err.log',  
      out_file: './logs/out.log',  
      log_file: './logs/combined.log',  
      time: true  
    }  
  ]  
};  
EOF  
  
    # Crear directorio de logs  
    mkdir -p logs  
  
    # Iniciar aplicación con PM2  
    pm2 start ecosystem.config.js  
    pm2 save  
    pm2 startup  
  
    print_status "Servicios configurados con PM2."  
}  
  
# Configurar servidor web (Nginx)  
setup_nginx() {  
    print_question "¿Deseas instalar y configurar Nginx como proxy reverso? (y/n) [y]: "  
    read -r INSTALL_NGINX  
    INSTALL_NGINX=${INSTALL_NGINX:-y}  
      
    if [[ $INSTALL_NGINX =~ ^[Yy]$ ]]; then  
        print_status "Instalando Nginx..."  
        sudo apt install -y nginx  
          
        # Configurar Nginx  
        sudo tee /etc/nginx/sites-available/izing << EOF  
server {  
    listen 80;  
    server_name _;  
      
    # Frontend  
    location / {  
        root $INSTALL_DIR/frontend/dist/spa;  
        index index.html;  
        try_files \$uri \$uri/ /index.html;  
    }  
      
    # API Backend  
    location /api {  
        proxy_pass http://localhost:$PROXY_PORT;  
        proxy_http_version 1.1;  
        proxy_set_header Upgrade \$http_upgrade;  
        proxy_set_header Connection 'upgrade';  
        proxy_set_header Host \$host;  
        proxy_set_header X-Real-IP \$remote_addr;  
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;  
        proxy_set_header X-Forwarded-Proto \$scheme;  
        proxy_cache_bypass \$http_upgrade;  
    }  
      
    # Socket.IO  
    location /socket.io/ {  
        proxy_pass http://localhost:$PROXY_PORT;  
        proxy_http_version 1.1;  
        proxy_set_header Upgrade \$http_upgrade;  
        proxy_set_header Connection "upgrade";  
        proxy_set_header Host \$host;  
        proxy_set_header X-Real-IP \$remote_addr;  
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;  
        proxy_set_header X-Forwarded-Proto \$scheme;  
    }  
}  
EOF  
          
        # Habilitar sitio  
        sudo ln -sf /etc/nginx/sites-available/izing /etc/nginx/sites-enabled/  
        sudo rm -f /etc/nginx/sites-enabled/default  
          
        # Verificar configuración y reiniciar Nginx  
        sudo nginx -t && sudo systemctl restart nginx  
        sudo systemctl enable nginx  
          
        print_status "Nginx configurado exitosamente."  
    fi  
}  
  
# Configurar firewall  
setup_firewall() {  
    print_question "¿Deseas configurar el firewall UFW? (y/n) [y]: "  
    read -r SETUP_FIREWALL  
    SETUP_FIREWALL=${SETUP_FIREWALL:-y}  
      
    if [[ $SETUP_FIREWALL =~ ^[Yy]$ ]]; then  
        print_status "Configurando firewall..."  
          
        sudo ufw --force enable  
        sudo ufw allow ssh  
        sudo ufw allow 80/tcp  
        sudo ufw allow 443/tcp  
        sudo ufw allow $BACKEND_PORT/tcp  
        sudo ufw allow $PROXY_PORT/tcp  
          
        print_status "Firewall configurado."  
    fi  
}  
  
# Mostrar información final  
show_final_info() {  
    print_status "¡Instalación completada exitosamente!"  
    echo  
    print_status "Información de la instalación:"  
    echo -e "📁 Directorio de instalación: ${GREEN}$INSTALL_DIR${NC}"  
    echo -e "🌐 Backend URL: ${GREEN}$BACKEND_URL:$BACKEND_PORT${NC}"  
    echo -e "🖥️  Frontend URL: ${GREEN}$FRONTEND_URL${NC}"  
    echo -e "🔄 Proxy URL: ${GREEN}$BACKEND_URL:$PROXY_PORT${NC}"  
    echo -e "🗄️  Base de datos: ${GREEN}$DB_NAME${NC} en ${GREEN}$DB_HOST:$DB_PORT${NC}"  
    echo  
    print_status "Comandos útiles:"  
    echo -e "• Ver logs: ${YELLOW}pm2 logs izing-backend${NC}"  
    echo -e "• Reiniciar: ${YELLOW}pm2 restart izing-backend${NC}"  
    echo -e "• Estado: ${YELLOW}pm2 status${NC}"  
    echo -e "• Parar: ${YELLOW}pm2 stop izing-backend${NC}"  
    echo  
    print_status "Accede a tu aplicación en: $FRONTEND_URL"  
    echo  
    print_warning "Credenciales por defecto (cámbialas después del primer login):"  
    echo "Usuario: admin@izing.io"  
    echo "Contraseña: 123456"  
}  
  
# Función principal  
main() {  
    clear  
    echo -e "${BLUE}"  
    echo "=================================="  
    echo "   INSTALADOR AUTOMÁTICO IZING"  
    echo "=================================="  
    echo -e "${NC}"  
    echo  
      
    print_status "Iniciando instalación de Izing en Ubuntu..."  
    echo  
      
    # Verificaciones  
    check_root  
      
    # Solicitar confirmación  
    print_question "¿Deseas continuar con la instalación? (y/n) [y]: "  
    read -r CONTINUE  
    CONTINUE=${CONTINUE:-y}  
      
    if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then  
        print_status "Instalación cancelada."  
        exit 0  
    fi  
      
    # Proceso de instalación  
    install_system_dependencies  
    setup_postgresql  
    setup_redis  
    get_app_configuration  
    install_application  
    setup_services  
    setup_nginx  
    setup_firewall  
    show_final_info  
}  
  
# Ejecutar función principal  
main "$@"
