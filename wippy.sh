#!/bin/bash
#
# Wippy (｡◕‿◕｡)
# Automatize your WordPress installation
#
# By @maximebj (maxime@smoothie-creative.com)
# https://bitbucket.org/dysign/wippy-spread/src
# More advanced fork :
# https://bitbucket.org/xfred/wippy-spread-advanced
# *** Recommended for Lazy people like me ***
#
# How to launch wippy ?
# bash wippy.sh sitename "My WP Blog"
# $1 = Website name, folder name & database name
# $2 = Site title


#  ============================
#  = Variables (to customize) =
#  ============================

# WordPress website settings
WP_DOMAIN=$1
WP_TITLE=$2
WP_URL="http://$WP_DOMAIN/" # Eg: "http://localhost:8888/my-project" or "http://monsite.fr"
WP_ADMIN="admin-$WP_DOMAIN"
WP_DESCRIPTION="Bienvenue sur le site $WP_TITLE"
WP_THEME="Sydney" # WP slug theme name ("twentysixteen"), path to a ZIP file or git repo URL ("git@github.com:…")

# WordPress local structure
WP_PATH="$HOME/Desktop/$WP_DOMAIN" # Folder to create , will deleted if exists. Use "$HOME" for home user directory.
WP_CORE_DIR="wp-cms" # To send WP core files in a specific folder. No slash. Default "" (empty = same as WP_PATH)
WP_CONTENT_DIR="wp-content" # To send WP content files in a specific folder. No slash. Default "wp-content"

# WordPress database settings
DB_HOST="127.0.0.1" # IP or domain for database. If "localhost" doesn't works, try "127.0.0.1"
DB_NAME=$WP_DOMAIN
DB_USER="root"
DB_PASSWORD="root" # "root" or "" (empty) for dev local
DB_PREFIX="k3d_" # Default "wp_". Only alphanumeric and underscore characters

# Wippy specific configuration
WIP_DIR=$(cd "$(dirname $0)";pwd -P) # !! DON'T MODIFY !! Absolute path of directory script.
WIP_PLUGIN_FILE="${WIP_DIR}/plugins.txt" # Path to plugins.txt. "$WIP_DIR" = same folder as wippy.sh
WIP_TREE_FILE="${WIP_DIR}/tree.txt" # Path to tree.txt. "$WIP_DIR" = same folder as wippy.sh


#  ===============
#  = Fancy Stuff =
#  ===============

# Clear terminal and stop on error
clear
set -e

# Colorize and formatting command line
# (256 color mode must be activate in Terminal or iTerm)
green='\x1B[0;32m'
cyan='\x1B[1;36m'
blue='\x1B[0;34m'
grey='\x1B[1;30m'
red='\x1B[0;91m'
magenta='\x1B[0;95m'
bold='\033[1m'
normal='\033[0m'

# Jump a line and display message (override echo function)
function echo {
  printf "%b\n" "$*"
}

# Wippy has something to say
function bot {
  echo
  echo "${blue}${bold}(｡◕‿◕｡)${normal}  $1"
}


#  ===============================================
#  = Checking for required commands availability =
#  ===============================================

# Welcome !
bot "${blue}${bold}Bonjour ! Je suis Wippy.${normal}"

# Check for PHP and WP-CLI installations
if ! type php &> /dev/null; then
  bot "Il semble que PHP n'est pas installé ou n'est pas dans votre \$PATH."
  echo "         Merci de vérifier et relancez-moi ensuite !"
  exit 1
elif ! type wp &> /dev/null; then
  bot "Il semble que WP-CLI n'est pas installé, je vais donc le télécharger…"
  mkdir -p $HOME/bin
  curl --progress-bar -o $HOME/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
  echo "         La version téléchargée est `php $HOME/bin/wp cli version`. Je l'ajoute à votre \$PATH…"
  chmod +x $HOME/bin/wp
  export PATH=$PATH:$HOME/bin
  if type wp &> /dev/null; then
    echo "         ${green}WP-CLI a été installé avec succès !${normal} Vous pouvez l'utiliser avec la commande 'wp'."
 fi
fi
# Adding mod_rewrite to WP-CLI config to regenerate .htaccess
if [ ! -e "$HOME/.wp-cli/config.yml" ]; then
  echo -e "apache_modules:\n  - mod_rewrite\n" >> "$HOME/.wp-cli/config.yml"
  chmod u+rw "$HOME/.wp-cli/config.yml"
fi

# Check for arguments
if [[ ! $2 ]]; then
  bot "Donnez-moi l'URL de votre site ainsi que le nom que vous voulez lui donner."
  echo "         Par exemple : ${grey}bash wippy.sh mon-site.fr \"Mon super blog WordPress\"${normal}"
  echo "         Ou encore : ${grey}bash wippy.sh localhost \"Un site génial\"${normal}"
  exit 1
else
  bot "Je vais installer WordPress pour votre site : ${cyan}$WP_TITLE${normal}"
fi


#  ===================================
#  = Checking for local working tree =
#  ===================================

# Check if provided folder name for WordPress install exists and is empty
if [ -d $WP_PATH ] && [ "$(ls -A $WP_PATH)" ]; then
  bot "${red}Le dossier ${cyan}${WP_PATH}${red} existe déjà et n'est pas vide${normal}."
  bot "${magenta}Voulez-vous que je supprime le dossier ?${normal} [o/N]"
  read DELETE
  if [[ $DELETE = [OoYy] ]]; then
    rm -rf $WP_PATH
    echo "         J'ai supprimé le dossier."
  else
    bot "Bien, je stoppe l'installation."
    exit 1
  fi
fi
if [ ! -d $WP_PATH ]; then
  bot "Je crée le dossier : ${cyan}$WP_PATH${normal}"
  mkdir -p $WP_PATH
fi

# Download WP
cd $WP_PATH
bot "Je télécharge WordPress…"
wp core download --locale=fr_FR --force

# Check version
bot "J'ai récupéré la version `wp core version` de WordPress"


#  =========================
#  = Checking for database =
#  =========================

# Create base configuration
bot "Je lance la configuration…"
wp core config --dbhost=$DB_HOST --dbname=$DB_NAME --dbuser=$DB_USER --dbpass=$DB_PASSWORD --dbprefix=$DB_PREFIX --skip-check --extra-php <<PHP
define( 'WP_DEBUG', true );
define( 'DISALLOW_FILE_EDIT', true );
define( 'WP_MEMORY_LIMIT', '96M' );
define( 'WP_CONTENT_DIR', dirname(__FILE__) . '/$WP_CONTENT_DIR' );
define( 'WP_CONTENT_URL', 'http://$WP_DOMAIN/$WP_CONTENT_DIR' );
PHP

# Check mysql availability
if ! type mysql &> /dev/null; then
  bot "Il semble que MySQL n'est pas installé ou n'est pas dans votre \$PATH."
  if [ -d /Applications/MAMP/ ]; then
    bot "J'ai trouvé MAMP sur votre système, je l'ajoute à votre \$PATH."
    export PATH=$PATH:/Applications/MAMP/Library/bin/
  else
    echo "         Essayez de l'installer et relancez-moi !"
    exit 1
  fi
fi

# Check database access
bot "Je vérifie l'accès à la base de données…"
SQLQ=`mysql -u $DB_USER -p$DB_PASSWORD --skip-column-names -e "SHOW DATABASES LIKE '$DB_NAME'"`
if [ "$SQLQ" == "$DB_NAME" ]; then
  bot "${red}J'ai trouvé une base de données nommée ${cyan}$DB_NAME${normal}."
  bot "${magenta}Voulez-vous que je supprime cette base de données ?${normal} [o/N]"
  read DELETE
  if [[ $DELETE = [OoYy] ]]; then
    wp db drop --yes
    echo "         J'ai supprimé la base de données."
  else
    bot "Bien, je stoppe l'installation."
    exit 1
  fi
fi

bot "Je créé la base de données…"
wp db create


#  =======================================
#  = Checking for WordPress installation =
#  =======================================

# Get admin email (= Git user.email if configured)
if type git &> /dev/null && git config --get user.email &> /dev/null; then
  EMAIL=`git config --get user.email`
elif [[ $1 == *.* ]]; then
  EMAIL="wp_admin@$1"
else
  EMAIL="wp_admin@$1.fr"
fi

# Launch WordPress install
bot "Et j'installe WordPress !"
PASSGEN=`head -c 10 /dev/random | base64` # Generate random password
PASSWORD=${PASSGEN:0:10}
wp core install --url=$WP_URL --title="$WP_TITLE" --admin_user=$WP_ADMIN --admin_email=$EMAIL --admin_password=$PASSWORD
echo $PASSWORD | pbcopy # Copy password in clipboard
bot "J'ai copié le mot de passe ${cyan}$PASSWORD${normal} dans le presse-papier."

# Restructuration
bot "Je restructure le dossier WordPress pour faciliter sa maintenance…"
cd $WP_PATH
[ -e readme.html ] && rm readme.html # Deleting readme file
[ -e license.txt ] && rm license.txt # Deleting license file
[ -e wp-config-sample.php ] && rm wp-config-sample.php # Deleting sample config file
echo "         J'ai supprimé les fichiers inutiles (readme, license et wp-config-sample)."
mkdir $WP_CORE_DIR
shopt -s extglob # Allow more advanced pattern matching
mv !($WP_CORE_DIR|$WP_CONTENT_DIR|wp-config.php|.htaccess) $WP_CORE_DIR
echo "         J'ai déplacé les fichiers du cœur de Wordpress dans le dossier \"$WP_CORE_DIR\""
cp $WP_CORE_DIR/index.php index.php
sed -i '' "s/\/wp-blog-header.php/\/$WP_CORE_DIR\/wp-blog-header.php/g" index.php
echo "         J'ai modifié le fichier index.php en conséquence."
if [ ! -e .htaccess ]; then
  echo "#### URL REWRITING CONFIG ####" >> .htaccess
  echo "<IfModule mod_rewrite.c>" >> .htaccess
  echo "  RewriteEngine On" >> .htaccess
  echo "  RewriteRule ^wp\-admin$ wp-admin/ [L,R=301]" >> .htaccess
  echo "  RewriteCond %{HTTP_HOST} ^(www.)?$WP_DOMAIN$" >> .htaccess
  echo "  RewriteCond %{REQUEST_URI} !^/$WP_CORE_DIR/" >> .htaccess
  echo "  RewriteCond %{REQUEST_FILENAME} !-f" >> .htaccess
  echo "  RewriteCond %{REQUEST_FILENAME} !-d" >> .htaccess
  echo "  RewriteRule ^(.*)$ /$WP_CORE_DIR/\$1" >> .htaccess
  echo "  RewriteCond %{HTTP_HOST} ^(www.)?$1$" >> .htaccess
  echo "  RewriteRule ^(/)?$ $WP_CORE_DIR/index.php [L] " >> .htaccess
  echo "</IfModule>" >> .htaccess
  echo "#### FILES PROTECTION CONFIG ####" >> .htaccess
  echo "<Files .htaccess>" >> .htaccess
  echo "    Order allow,deny" >> .htaccess
  echo "    Deny from all" >> .htaccess
  echo "</Files>" >> .htaccess
  echo "<Files wp-config.php>" >> .htaccess
  echo "    Order allow,deny" >> .htaccess
  echo "    Deny from all" >> .htaccess
  echo "</Files>" >> .htaccess
  echo "         J'ai créé le fichier .htaccess qui convient."
fi


#  ==================================
#  = Plugins and theme installation =
#  ==================================

# Plugins install
bot "J'installe les plugins de la liste et je met à jour ceux qui le nécessitent…"
cd $WP_PATH/$WP_CORE_DIR
while IFS=$' \t\n\r' read -r PLUGIN  || [ -n "$PLUGIN" ] # Fix Posix ignored last line
do
  # Ignore comments and new linebreaks
  if [[ $PLUGIN != \#* ]] && [ -n "$PLUGIN" ]; then
    wp plugin install $PLUGIN --activate
  fi
done < $WIP_PLUGIN_FILE
wp plugin update --all # Update all plugins even already installed

# Download and install WordPress theme
bot "Je télécharge le thème désiré…"
if [[ $WP_THEME =~ ^git@* ]] && git ls-remote $WP_THEME &> /dev/null; then
  cd $WP_PATH/$WP_CONTENT_DIR/themes/
  git clone $WP_THEME
  WP_THEME=`basename $WP_THEME .git`
  wp theme activate $WP_THEME
else
  wp theme install $WP_THEME --activate
fi
THEME_PATH=$(wp theme path $WP_THEME --dir)


#  ===========================
#  = Cleaning useless stuffs =
#  ===========================

# Cleanup
bot "Je supprime Hello Dolly, les thèmes de base et les articles exemples…"
wp plugin delete hello
wp theme delete twentyfifteen
wp theme delete twentysixteen
wp theme delete twentyseventeen
wp post delete $(wp post list --post_type='page' --format=ids) --force
wp post delete $(wp post list --post_type='post' --format=ids) --force
wp term update category 1 --name="Nouveautés" # Rename default "uncategorized" category


#  ============================
#  = WordPress tree structure =
#  ============================

# Create standard pages
bot "Je met en place l'arborescence du site…"
FIRST_MENU=1 # Var only for main menu
HOMEPAGE=1 # Var for homepage
while read -r TREE_LINE  || [ -n "$TREE_LINE" ] # Fix Posix ignored last line
do
  # Ignore comments and new linebreaks
  if [[ $TREE_LINE != \#* ]] && [ -n "$TREE_LINE" ]; then
    # If undescore, it's a menu page
    if [[ "$TREE_LINE" =~ ^_.* ]]; then
      # Level 3 page
      if [[ "$TREE_LINE" =~ ^___.* ]]; then
        TREE_LINE_TRIM="${TREE_LINE//_/}"
        POST_ID="$(wp post create --porcelain --post_type=page --post_status=publish --post_title="$TREE_LINE_TRIM")"
        echo "Page de niveau 3 ${cyan}"$TREE_LINE_TRIM"${normal} créée (ID $POST_ID - Page parente $REF_P2)"
        wp menu item add-post "$REF_MENU" $POST_ID --parent-id=`expr $REF_P2 + 1`
      # Level 2 page
      elif [[ "$TREE_LINE" =~ ^__.* ]]; then
        TREE_LINE_TRIM="${TREE_LINE//_/}"
        POST_ID="$(wp post create --porcelain --post_type=page --post_status=publish --post_title="$TREE_LINE_TRIM")"
        echo "Page de niveau 2 ${cyan}"$TREE_LINE_TRIM"${normal} créée (ID $POST_ID - Page parente $REF_P1)"
        REF_P2=$POST_ID
        wp menu item add-post "$REF_MENU" $POST_ID --parent-id=`expr $REF_P1 + 1`
      # Level 1 page
      else
        TREE_LINE_TRIM="${TREE_LINE//_/}"
        POST_ID="$(wp post create --porcelain --post_type=page --post_status=publish --post_title="$TREE_LINE_TRIM")"
        echo "Page de niveau 1 ${cyan}"$TREE_LINE_TRIM"${normal} créée (ID $POST_ID - Menu parent $REF_MENU)"
        REF_P1=$POST_ID
        REF_P2=""
        wp menu item add-post "$REF_MENU" $POST_ID
        [[ $HOMEPAGE = 1 ]] && wp option update page_on_front $POST_ID && HOMEPAGE=0 # Page ID displayed on front page (homepage)
      fi
    # If arobase, it's a standalone page
    elif [[ "$TREE_LINE" =~ ^@.* ]]; then
        TREE_LINE_TRIM="${TREE_LINE//@/}"
        POST_ID="$(wp post create --porcelain --post_type=page --post_status=publish --post_title="$TREE_LINE_TRIM")"
        echo "Page seule ${cyan}"$TREE_LINE_TRIM"${normal} créée (ID $POST_ID)"
        [[ $HOMEPAGE = 1 ]] && wp option update page_on_front $POST_ID && HOMEPAGE=0 # Page ID displayed on front page (homepage)
    # Else it's a menu
    else
      MENU_ID="$(wp menu create --porcelain "$TREE_LINE")"
      echo "Je crée le menu : ${cyan}"$TREE_LINE"${normal}  (ID $MENU_ID)"
      REF_MENU=$MENU_ID
      REF_P1=""
      REF_P2=""
      if [[ $FIRST_MENU = 1 ]]; then
        # Get primary menu location name of theme (usually "primary" or "top")
        LOC_MENU_NAME=$(wp menu location list --format=ids | awk '{print $1;}')
        wp menu location assign "$TREE_LINE" "$LOC_MENU_NAME"
      fi
      FIRST_MENU=0
    fi
  fi
done < $WIP_TREE_FILE


#  ===============================
#  = Options & security settings =
#  ===============================

# Change some options
# Doc : https://codex.wordpress.org/Option_Reference
bot "J'applique quelques modifications de paramètres…"
wp option update show_on_front page # A static page as homepage. Default : latest posts
wp option update page_for_posts 4 # Page ID that displays posts (blog)
wp option update category_base theme # Default category base for categories permalink
wp option update tag_base sujet # Default tag base for tags permalink
wp option update blogdescription "$WP_DESCRIPTION" # Set a description of website
wp option update default_comment_status 0 # Disable comments, overridable by post
wp option update comment_registration 1 # Users must be logged in to comment
wp option update uploads_use_yearmonth_folders 0 # Disable year/month folders for medias

# Security misc
bot "Je sécurise Wordpress, masque les infos de version, désactive les flux RSS…"
echo "remove_action( 'wp_head', ' wp_generator' );" >> "$THEME_PATH/functions.php" # Remove WP version
echo "remove_action( 'wp_head', 'wlwmanifest_link' );" >> "$THEME_PATH/functions.php" # Disable Windows Live Writer service
echo "remove_action( 'wp_head', 'rsd_link' );" >> "$THEME_PATH/functions.php" # Disable Really Simple Discovery service
echo "function disable_version() { return ''; } " >> "$THEME_PATH/functions.php"
echo "add_filter( 'the_generator', 'disable_version' );" >> "$THEME_PATH/functions.php" # Disable WP version info
echo "add_filter( 'login_errors', create_function('$a', \"return null;\") );" >> "$THEME_PATH/functions.php" # Disable login errors
echo "function wpb_disable_feed() {" >> "$THEME_PATH/functions.php" # Disable feeds
echo "wp_die( __( 'No feed available. Please visit our <a href=\"'. get_bloginfo('url') .'\">homepage</a>!') );}" >> "$THEME_PATH/functions.php"
echo "add_action( 'do_feed', 'wpb_disable_feed',1 );" >> "$THEME_PATH/functions.php"
echo "add_action( 'do_feed_rdf', 'wpb_disable_feed',1 );" >> "$THEME_PATH/functions.php"
echo "add_action( 'do_feed_rss', 'wpb_disable_feed',1 );" >> "$THEME_PATH/functions.php"
echo "add_action( 'do_feed_rss2', 'wpb_disable_feed',1 );" >> "$THEME_PATH/functions.php"
echo "add_action( 'do_feed_atom', 'wpb_disable_feed',1 );" >> "$THEME_PATH/functions.php"
echo "add_action( 'do_feed_rss2_comments', 'wpb_disable_feed', 1 );" >> "$THEME_PATH/functions.php"
echo "add_action( 'do_feed_atom_comments', 'wpb_disable_feed', 1 );" >> "$THEME_PATH/functions.php"

# Permalinks to /%postname%/
bot "J'active la structure des permaliens et regénère le .htaccess…"
wp rewrite structure "/%postname%/" --hard
wp rewrite flush --hard # Regenerate .htaccess file


#  ===============
#  = Versionning =
#  ===============

# Git project
if type git &> /dev/null; then
  bot "Je versionnne le projet avec Git…"
  cd $WP_PATH
  git init # Init a git project
  if [ ! -e .gitignore ]; then
    echo "$WP_CORE_DIR/*" >> .gitignore
    echo "$WP_CONTENT_DIR/uploads" >> .gitignore
    echo "$WP_CONTENT_DIR/plugins" >> .gitignore
    echo "$WP_CONTENT_DIR/cache" >> .gitignore
    echo "$WP_CONTENT_DIR/upgrade" >> .gitignore
    echo "$WP_CONTENT_DIR/blogs.dir" >> .gitignore
    echo "$WP_CONTENT_DIR/advanced-cache.php" >> .gitignore
    echo "$WP_CONTENT_DIR/wp-cache-config.php" >> .gitignore
    echo "/wp-config.php" >> .gitignore
    echo "/sitemap.xml*" >> .gitignore
    echo "*.log" >> .gitignore
    echo "         J'ai créé le fichier .gitignore qui convient."
  fi
  # Add WP as submode to easy Git update
  # git submodule add https://github.com/wordpress/wordpress $WP_CORE_DIR
  # cd $WP_CORE_DIR
  # git fetch --tags
  # git checkout 4.8.2
  # echo "         J'ai ajouté WordPress en tant que submodule."
  git add -A # Add all untracked files
  git commit --quiet -m "Initial commit" # Commit changes
  echo "         Projet versionné avec succès."
fi


#  ==================
#  = Launching apps =
#  ==================

# Open default browser
bot "Je lance le navigateur, Sublime Text et le Finder…"
open $WP_URL # Open front-office page
open "${WP_URL}wp-admin" # Open back-office page

# Open theme folder in Sublime text
# Doc : https://www.sublimetext.com/docs/3/osx_command_line.html
if ! type subl &> /dev/null; then
  if [ -d "/Applications/Sublime Text"* ]; then
    ln -s "/Applications/Sublime Text"*"/Contents/SharedSupport/bin/subl" ~/bin/subl
  else
    bot "         Je ne parviens pas à localiser Sublime Text."
  fi
fi
if type subl &> /dev/null; then
  subl $THEME_PATH
fi

# Open Finder
open $WP_PATH # Window to WordPress root path


#  =====================
#  = That's all folks! =
#  =====================

# Install summary
bot "${green}Wippy yeah ! L'installation est terminée !${normal}"
echo
echo "         Voici un récapitulatif des informations à conserver :"
echo
echo "         URL du site :     ${cyan}$WP_URL${normal}"
echo "         URL de l'admin :  ${cyan}${WP_URL}wp-admin${normal}"
echo "         Login admin :     ${cyan}$WP_ADMIN${normal}"
echo "         Email admin :     ${cyan}$EMAIL${normal}"
echo "         Password :        ${cyan}${bold}$PASSWORD${normal}${grey} (Copié dans le presse-papier !)${normal}"
echo
bot "${blue}${bold}À bientôt !${normal}"
echo
