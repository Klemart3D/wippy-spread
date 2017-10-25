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

# WordPress settings
wp_url="http://"$1"/" # "http://localhost:8888/my-project" or "http://monsite.fr"
wp_admin="admin-$1"
wp_install_path="$HOME/Desktop" # Use "$HOME" instead of "~"" (tilde) for home user directory
wp_title=$2
wp_description="Bienvenue sur le site de $wp_title"

# Database settings
db_host="127.0.0.1" # Default "localhost". If doesn't works try "127.0.0.1"
db_name=$1
db_user="root"
db_password="root" # "root" ou "" (empty) for dev local

# Absolute path of directory script. !! DON'T MODIFY !!
wippy_dir=$(cd "$(dirname $0)";pwd -P)

# Plugins : path to plugins.txt
pluginfilepath="$wippy_dir/plugins.txt" # "$wippy_dir" = same folder as wippy.sh

# Menu tree : path to tree.txt
wp_tree_file="$wippy_dir/tree.txt" # "$wippy_dir" = same folder as wippy.sh

# Theme : WordPress slug theme name ("twentysixteen"), path to a ZIP file or git URL ("git@github.com:…")
wp_theme="Sydney"


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


#  ==============================
#  = The show is about to begin =
#  ==============================

# Welcome !
bot "${blue}${bold}Bonjour ! Je suis Wippy. $script_dir${normal}"

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
  bot "Je vais installer WordPress pour votre site : ${cyan}$wp_title${normal}"
fi

# Check if provided folder name for WordPress install exists and is empty
pathtoinstall=${wp_install_path}/$1
if [ -d $pathtoinstall ] && [ "$(ls -A $pathtoinstall)" ]; then
  bot "${red}Le dossier ${cyan}${pathtoinstall}${red} existe déjà et n'est pas vide${normal}."
  bot "${magenta}Voulez-vous que je supprime le dossier ?${normal} [o/N]"
  read DELETE
  if [[ $DELETE = [OoYy] ]]; then 
    rm -rf $pathtoinstall
    echo "         J'ai supprimé le dossier."
  else
    bot "Bien, je stoppe l'installation."
    exit 1
  fi
fi
if [ ! -d $pathtoinstall ]; then
  bot "Je crée le dossier : ${cyan}$pathtoinstall${normal}"
  mkdir -p $pathtoinstall
fi

# Download WP
cd $pathtoinstall
bot "Je télécharge WordPress…"
wp core download --locale=fr_FR --force

# Check version
bot "J'ai récupéré la version `wp core version` de WordPress"

# Create base configuration
bot "Je lance la configuration…"
wp core config --dbhost=$db_host --dbname=$db_name --dbuser=$db_user --dbpass=$db_password --dbprefix=k3d_ --skip-check --extra-php <<PHP
define( 'WP_DEBUG', true );
define( 'DISALLOW_FILE_EDIT', true );
define( 'WP_CONTENT_DIR', dirname(__FILE__) . '/wp-content' );
define( 'WP_CONTENT_URL', 'http://$1/wp-content' );
PHP

# Create database
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

bot "Je vérifie l'accès à la base de données…"
sql_cmd=`mysql -u $db_user -p$db_password --skip-column-names -e "SHOW DATABASES LIKE '$db_name'"`
if [ "$sql_cmd" == "$db_name" ]; then
  bot "${red}J'ai trouvé une base de données nommée ${cyan}$db_name${normal}."
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

# Get admin email (= Git user.email if configured)
if type git &> /dev/null && git config --get user.email &> /dev/null; then
  email=`git config --get user.email`
elif [[ $1 == *.* ]]; then
  email="wp_admin@$1"
else
  email="wp_admin@$1.fr"
fi

# Launch WordPress install
bot "Et j'installe WordPress !"
passgen=`head -c 10 /dev/random | base64` # Generate random password
password=${passgen:0:10} 
wp core install --url=$wp_url --title="$wp_title" --admin_user=$wp_admin --admin_email=$email --admin_password=$password
echo $password | pbcopy # Copy password in clipboard
bot "J'ai copié le mot de passe ${cyan}$password${normal} dans le presse-papier !"

# Restructuration
bot "Je restructure le dossier WordPress pour faciliter sa maintenance…"
cd $pathtoinstall
mkdir wp-cms
shopt -s extglob # Allow more advanced pattern matching
mv !(wp-cms|wp-content|wp-config.php|.htaccess) wp-cms
echo "         J'ai déplacé les fichiers du cœur de Wordpress dans le dossier \"wp-cms\""
cp wp-cms/index.php index.php
sed -i '' "s/\/wp-blog-header.php/\/wp-cms\/wp-blog-header.php/g" index.php
echo "         J'ai modifié le fichier index.php en conséquence."
if [ ! -e .htaccess ]; then
  echo "<IfModule mod_rewrite.c>" >> .htaccess
  echo "  RewriteEngine On" >> .htaccess
  echo "  RewriteCond %{HTTP_HOST} ^(www.)?$1$" >> .htaccess
  echo "  RewriteCond %{REQUEST_URI} !^/wp-cms/" >> .htaccess
  echo "  RewriteCond %{REQUEST_FILENAME} !-f" >> .htaccess
  echo "  RewriteCond %{REQUEST_FILENAME} !-d" >> .htaccess
  echo "  RewriteRule ^(.*)$ /wp-cms/\$1" >> .htaccess
  echo "  RewriteCond %{HTTP_HOST} ^(www.)?$1$" >> .htaccess
  echo "  RewriteRule ^(/)?$ wp-cms/index.php [L] " >> .htaccess
  echo "</IfModule>" >> .htaccess
  echo "         J'ai créé le fichier .htaccess qui convient."
fi

# Plugins install
bot "J'installe les plugins de la liste et je met à jour ceux qui le nécessitent…"
cd $pathtoinstall/wp-cms
while IFS=$' \t\n\r' read -r plugin  || [ -n "$plugin" ] # Fix Posix ignored last line
do
  # Ignore comments and new linebreaks
  if [[ $plugin != \#* ]] && [ -n "$plugin" ]; then
    wp plugin install $plugin --activate
  fi 
done < $pluginfilepath
wp plugin update --all # Update all plugins even already installed

# Download and install WordPress theme
bot "Je télécharge le thème désiré…"
if [[ $wp_theme =~ ^git@* ]] && git ls-remote $wp_theme &> /dev/null; then
  cd $pathtoinstall/wp-content/themes/
  git clone $wp_theme
  wp_theme=`basename $wp_theme .git`
  wp theme activate $wp_theme
else
  wp theme install $wp_theme --activate 
fi
theme_path=$(wp theme path $wp_theme --dir)

# Cleanup
bot "Je supprime Hello Dolly, les thèmes de base et les articles exemples…"
wp plugin delete hello
wp theme delete twentyfifteen
wp theme delete twentysixteen
wp theme delete twentyseventeen
wp post delete $(wp post list --post_type='page' --format=ids) --force
wp post delete $(wp post list --post_type='post' --format=ids) --force
wp term update category 1 --name="Nouveautés" # Rename default "uncategorized" category 
[ -e "$pathtoinstall/wp-config-sample.php" ] && rm "$pathtoinstall/wp-config-sample.php" # Deleting sample config file

# Create standard pages
bot "Je met en place l'arborescence du site…"
first_menu=1 # Var only for main menu
homepage=1 # Var for homepage
while read -r tree_line  || [ -n "$tree_line" ] # Fix Posix ignored last line
do
  # Ignore comments and new linebreaks
  if [[ $tree_line != \#* ]] && [ -n "$tree_line" ]; then
    # If undescore, it's a menu page
    if [[ "$tree_line" =~ ^_.* ]]; then
      # Level 3 page
      if [[ "$tree_line" =~ ^___.* ]]; then
        tree_line_trim="${tree_line//_/}"
        post_id="$(wp post create --porcelain --post_type=page --post_status=publish --post_title="$tree_line_trim")"
        echo "Page de niveau 3 ${cyan}"$tree_line_trim"${normal} créée (ID $post_id - Page parente $ref_p2)"
        wp menu item add-post "$ref_menu" $post_id --parent-id=`expr $ref_p2 + 1`
      # Level 2 page  
      elif [[ "$tree_line" =~ ^__.* ]]; then
        tree_line_trim="${tree_line//_/}"
        post_id="$(wp post create --porcelain --post_type=page --post_status=publish --post_title="$tree_line_trim")"
        echo "Page de niveau 2 ${cyan}"$tree_line_trim"${normal} créée (ID $post_id - Page parente $ref_p1)"
        ref_p2=$post_id
        wp menu item add-post "$ref_menu" $post_id --parent-id=`expr $ref_p1 + 1`
      # Level 1 page
      else
        tree_line_trim="${tree_line//_/}"
        post_id="$(wp post create --porcelain --post_type=page --post_status=publish --post_title="$tree_line_trim")"
        echo "Page de niveau 1 ${cyan}"$tree_line_trim"${normal} créée (ID $post_id - Menu parent $ref_menu)"
        ref_p1=$post_id
        ref_p2=""
        wp menu item add-post "$ref_menu" $post_id
        [[ $homepage = 1 ]] && wp option update page_on_front $post_id && homepage=0 # Page ID displayed on front page (homepage)
      fi
    # If arobase, it's a standalone page  
    elif [[ "$tree_line" =~ ^@.* ]]; then
        tree_line_trim="${tree_line//@/}"
        post_id="$(wp post create --porcelain --post_type=page --post_status=publish --post_title="$tree_line_trim")"
        echo "Page seule ${cyan}"$tree_line_trim"${normal} créée (ID $post_id)"
        [[ $homepage = 1 ]] && wp option update page_on_front $post_id && homepage=0 # Page ID displayed on front page (homepage)
    # Else it's a menu   
    else
      menu_id="$(wp menu create --porcelain "$tree_line")"
      echo "Je crée le menu : ${cyan}"$tree_line"${normal}  (ID $menu_id)"
      ref_menu=$menu_id
      ref_p1=""
      ref_p2=""
      [[ $first_menu = 1 ]] && wp menu location assign "$tree_line" primary
      first_menu=0
    fi
  fi 
done < $wp_tree_file

# Change some options
# Doc : https://codex.wordpress.org/Option_Reference
bot "J'applique quelques modifications de paramètres…"
wp option update show_on_front page # A static page as homepage. Default : latest posts
wp option update page_for_posts 4 # Page ID that displays posts (blog)
wp option update category_base theme # Default category base for categories permalink
wp option update tag_base sujet # Default tag base for tags permalink
wp option update blogdescription "$wp_description" # Set a description of website
wp option update default_comment_status 0 # Disable comments, overridable by post
wp option update comment_registration 1 # Users must be logged in to comment 
wp option update uploads_use_yearmonth_folders 0 # Disable year/month folders for medias

# Security misc
bot "Je sécurise Wordpress, masque les infos de version, désactive les flux RSS…"
echo "remove_action( 'wp_head', ' wp_generator' );" >> "$theme_path/functions.php" # Remove WP version
echo "remove_action( 'wp_head', 'wlwmanifest_link' );" >> "$theme_path/functions.php" # Disable Windows Live Writer service
echo "remove_action( 'wp_head', 'rsd_link' );" >> "$theme_path/functions.php" # Disable Really Simple Discovery service
echo "function disable_version() { return ''; } " >> "$theme_path/functions.php"
echo "add_filter( 'the_generator', 'disable_version' );" >> "$theme_path/functions.php" # Disable WP version info
echo "add_filter( 'login_errors', create_function('$a', \"return null;\") );" >> "$theme_path/functions.php" # Disable login errors
echo "function wpb_disable_feed() {" >> "$theme_path/functions.php" # Disable feeds
echo "wp_die( __( 'No feed available. Please visit our <a href=\"'. get_bloginfo('url') .'\">homepage</a>!') );}" >> "$theme_path/functions.php"
echo "add_action( 'do_feed', 'wpb_disable_feed',1 );" >> "$theme_path/functions.php"
echo "add_action( 'do_feed_rdf', 'wpb_disable_feed',1 );" >> "$theme_path/functions.php"
echo "add_action( 'do_feed_rss', 'wpb_disable_feed',1 );" >> "$theme_path/functions.php"
echo "add_action( 'do_feed_rss2', 'wpb_disable_feed',1 );" >> "$theme_path/functions.php"
echo "add_action( 'do_feed_atom', 'wpb_disable_feed',1 );" >> "$theme_path/functions.php"
echo "add_action( 'do_feed_rss2_comments', 'wpb_disable_feed', 1 );" >> "$theme_path/functions.php"
echo "add_action( 'do_feed_atom_comments', 'wpb_disable_feed', 1 );" >> "$theme_path/functions.php"
[ -e "$pathtoinstall/readme.html" ] && rm "$pathtoinstall/readme.html" # Deleting readme file
[ -e "$pathtoinstall/license.txt" ] && rm "$pathtoinstall/license.txt" # Deleting license file

# Permalinks to /%postname%/
bot "J'active la structure des permaliens et regénère le .htaccess…"
wp rewrite structure "/%postname%/" --hard
wp rewrite flush --hard # Regenerate .htaccess file

# Git project
if type git &> /dev/null; then
  bot "Je versionnne le projet avec Git…"
  cd $pathtoinstall
  git init # Init a git project
  git add -A # Add all untracked files
  git commit --quiet -m "Initial commit" # Commit changes
  echo "         Projet versionné avec succès."
fi

# Launching apps
bot "Je lance le navigateur, Sublime Text et le Finder…"
open $wp_url # Open front-office in browser
open "${wp_url}wp-admin" # Open back-office in browser
# Open in Sublime text
# Doc : https://www.sublimetext.com/docs/3/osx_command_line.html
if ! type subl &> /dev/null; then
  if [ -d "/Applications/Sublime Text"* ]; then
    ln -s "/Applications/Sublime Text"*"/Contents/SharedSupport/bin/subl" ~/bin/subl
  else
    bot "         Je ne parviens pas à localiser Sublime Text."
  fi
fi
if type subl &> /dev/null; then
  subl $theme_path
fi  
open $pathtoinstall # Open in Finder


#  ======================
#  = That's all folks ! =
#  ======================

# Install summary
bot "${green}Wippy yeah ! L'installation est terminée !${normal}"
echo
echo "         Voici un récapitulatif des informations à conserver :"
echo
echo "         URL du site :     ${cyan}$wp_url${normal}"
echo "         URL de l'admin :  ${cyan}${wp_url}wp-admin${normal}"
echo "         Login admin :     ${cyan}$wp_admin${normal}"
echo "         Email admin :     ${cyan}$email${normal}"
echo "         Password :        ${cyan}${bold}$password${normal}${grey} (Déjà copié dans le presse-papier !)${normal}"
echo
bot "${blue}${bold}À bientôt !${normal}"
echo
