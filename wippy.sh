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

# Database settings
db_host="127.0.0.1" # Default "localhost". If doesn't works try "127.0.0.1"
db_name=$1
db_user="root"
db_password="root" # "root" ou "" (empty) for dev local

# Path to plugins.txt
pluginfilepath="$PWD/plugins.txt" # "$PWD" = same folder as wippy.sh

#  ===============
#  = Fancy Stuff =
#  ===============

# Stop on error
set -e

# Colorize and formatting command line
# (256 color mode must be activate in Terminal or iTerm)
green='\x1B[0;32m'
cyan='\x1B[1;36m'
blue='\x1B[0;34m'
grey='\x1B[1;30m'
red='\x1B[0;31m'
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

# Check for arguments
if [[ ! $2 ]]; then
  bot "Donnez-moi l'URL de votre site ainsi que le nom que vous voulez lui donner."
  echo "         Par exemple : ${grey}bash wippy.sh mon-site.fr \"Mon super blog WordPress\"${normal}"
  echo "         Ou encore : ${grey}bash wippy.sh localhost \"Un site génial\"${normal}"
  exit 1
else
  bot "Je vais installer WordPress pour votre site : ${cyan}$2${normal}"
fi

# Check if provided folder name for WordPress install exists and is empty
pathtoinstall=${wp_install_path}/$1
if [ ! -d $pathtoinstall ]; then
  bot "Je crée le dossier : ${cyan}$pathtoinstall${normal}"
  mkdir -p $pathtoinstall
elif [ -d $pathtoinstall ] && [ "$(ls -A $pathtoinstall)" ]; then
  bot "${red}Le dossier ${cyan}${pathtoinstall}${red} existe déjà et n'est pas vide${normal}."
  echo "         Par sécurité, je ne vais pas plus loin pour ne rien écraser."
  echo
  exit 1
fi

# Download WP
cd $pathtoinstall
bot "Je télécharge WordPress…"
wp core download --locale=fr_FR --force

# Check version
bot "J'ai récupéré la version `wp core version` de WordPress"

# Create base configuration
bot "Je lance la configuration…"
wp core config --dbhost=$db_host --dbname=$db_name --dbuser=$db_user --dbpass=$db_password --skip-check --extra-php <<PHP
define( 'WP_DEBUG', true );
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
sql_query=`mysql -u $db_user -p$db_password --skip-column-names -e "SHOW DATABASES LIKE '$db_name'"`
if [ "$sql_query" == "$db_name" ]; then
  sql_query2=`mysql -u $db_user -p$db_password --skip-column-names -e "SELECT count(*) FROM information_schema.tables WHERE table_type = 'BASE TABLE' AND table_schema = '$db_name'"`
  if [ "$sql_query2" == 0 ]; then
    echo "         J'ai trouvé une base de données vide ${cyan}$db_name${normal}. Je la supprime…"
    wp db drop --yes
  else
    echo "         ${red}J'ai trouvé une base de données non vide nommée ${cyan}$db_name${normal}."
    echo "         Par sécurité je ne vais pas plus loin pour ne rien écraser."
    echo
    exit 1
  fi
else
  bot "Je créé la base de données…"
  wp db create
fi

# Get admin email (= Git user.email if configured)
if type git &> /dev/null && git config --get user.email &> /dev/null; then
  email=`git config --get user.email`
elif [[ $1 == *.* ]]; then
  email="wp_admin@$1"
else
  email="wp_admin@$1.fr"
fi

# Generate random password
passgen=`head -c 10 /dev/random | base64`
password=${passgen:0:10}

# Launch install
bot "Et j'installe WordPress !"
wp core install --url=$wp_url --title="$2" --admin_user=$wp_admin --admin_email=$email --admin_password=$password

# Plugins install
bot "J'installe les plugins à partir de la liste des plugins…"
while IFS=$' \t\n\r' read -r plugin
do
  # Ignore comments and new linebreaks
  if [[ $plugin != \#* ]] && [ -n "$plugin" ]; then
    wp plugin install $plugin --activate
  fi 
done < $pluginfilepath

# Download from private git repository
bot "Je télécharge le thème WP0 theme…"
cd wp-content/themes/
git clone git@bitbucket.org:maximebj/wordpress-zero-theme.git
wp theme activate $1

# Create standard pages
bot "Je crée les pages habituelles (Accueil, blog, contact...)…"
wp post create --post_type=page --post_title='Accueil' --post_status=publish
wp post create --post_type=page --post_title='Blog' --post_status=publish
wp post create --post_type=page --post_title='Contact' --post_status=publish
wp post create --post_type=page --post_title='Mentions Légales' --post_status=publish

# Create fake posts
bot "Je crée quelques faux articles…"
curl http://loripsum.net/api/5 | wp post generate --post_content --count=5

# Change Homepage
bot "Je change la page d'accueil et la page des articles…"
wp option update show_on_front page
wp option update page_on_front 3
wp option update page_for_posts 4

# Menu stuff
bot "Je crée le menu principal, assigne les pages, et je lie l'emplacement du thème…"
wp menu create "Menu Principal"
wp menu item add-post menu-principal 3
wp menu item add-post menu-principal 4
wp menu item add-post menu-principal 5
wp menu location assign menu-principal main-menu

# Misc cleanup
bot "Je supprime Hello Dolly, les thèmes de base et les articles exemples…"
wp post delete 1 --force # Article exemple - no trash. Comment is also deleted
wp post delete 2 --force # page exemple
wp plugin delete hello
wp theme delete twentytwelve
wp theme delete twentythirteen
wp theme delete twentyfourteen
wp option update blogdescription ''

# Permalinks to /%postname%/
bot "J'active la structure des permaliens…"
wp rewrite structure "/%postname%/" --hard
wp rewrite flush --hard

# cat and tag base update
wp option update category_base theme
wp option update tag_base sujet

# Git project
# REQUIRED : download Git at http://git-scm.com/downloads
bot "Je Git le projet…"
cd ../..
git init    # git project
git add -A  # Add all untracked files
git commit -m "Initial commit"   # Commit changes

# Open the stuff
bot "Je lance le navigateur, Sublime Text et le finder…"

# Open in browser
open $url
open "${wp_url}wp-admin"

# Open in Sublime text
# REQUIRED : activate subl alias at https://www.sublimetext.com/docs/3/osx_command_line.html
cd wp-content/themes
subl $1

# Open in finder
cd $1
open .

# Copy password in clipboard
echo $password | pbcopy

# That's all ! Install summary
bot "${green}L'installation est terminée !${normal}"
echo
echo "URL du site:   $wp_url"
echo "Login admin :  $wp_admin"
echo "Password :  ${cyan}${bold} $password ${normal}${normal}"
echo
echo "${grey}(N'oubliez pas le mot de passe ! Je l'ai copié dans le presse-papier)${normal}"

echo
bot "À bientôt !"
echo
echo
