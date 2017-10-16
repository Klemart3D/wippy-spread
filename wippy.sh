#!/bin/bash
#
# Wippy (｡◕‿◕｡)
# Automatize your WordPress installation
#
# By @maximebj (maxime@smoothie-creative.com)
#
# *** Recommended for Lazy people like me ***
#
# How to launch wippy ?
# bash wippy.sh sitename "My WP Blog"
# $1 = folder name & database name
# $2 = Site title


# VARS 
# admin email (= Git user.email if configured)
if type git &> /dev/null && git config --get user.email &> /dev/null; then
  email=`git config --get user.email`
elif [[ $1 == *.* ]]; then
  email="email@$1"
else
  email="email@$1.fr"
fi

# local url login
# --> Change to fit your server URL model (eg: http://localhost:8888/my-project)
url="http://"$1":8888/"

# admin login
admin="admin-$1"

# path to install your WPs
# --> use "$HOME" instead of "~"" (tilde) for home user directory
installpath="$HOME/Desktop"

# path to plugins.txt
pluginfilepath="~/path/to/wippy/plugins.txt"

# end VARS ---




#  ===============
#  = Fancy Stuff =
#  ===============
# not mandatory at all

# Stop on error
set -e

# colorize and formatting command line
# You need iTerm and activate 256 color mode in order to work : http://kevin.colyar.net/wp-content/uploads/2011/01/Preferences.jpg
green='\x1B[0;32m'
cyan='\x1B[1;36m'
blue='\x1B[0;34m'
grey='\x1B[1;30m'
red='\x1B[0;31m'
bold='\033[1m'
italic='\033[3m'
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
  echo "         Par exemple : ${grey}${italic}bash wippy.sh mon-site.fr \"Mon super blog WordPress\"${normal}"
  echo "         Ou encore : ${grey}${italic}bash wippy.sh localhost \"Un site génial\"${normal}"
  exit 1
else
  bot "Je vais installer WordPress pour votre site : ${cyan}$2${normal}"
fi

# Check if provided folder name for WordPress install exists and is empty
pathtoinstall=${installpath}/$1
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
bot "Je télécharge WordPress..."
wp core download --locale=fr_FR --force

# check version
bot "J'ai récupéré cette version :"
wp core version

# create base configuration
bot "Je lance la configuration :"
wp core config --dbname=$1 --dbuser=root --dbpass=root --skip-check --extra-php <<PHP
define( 'WP_DEBUG', true );
PHP

# Create database
bot "Je crée la base de données :"
wp db create

# Generate random password
passgen=`head -c 10 /dev/random | base64`
password=${passgen:0:10}

# launch install
bot "et j'installe !"
wp core install --url=$url --title="$2" --admin_user=$admin --admin_email=email --admin_password=$password

# Plugins install
bot "J'installe les plugins à partir de la liste des plugins :"
while read echo || [ -n "$echo" ]
do
    wp plugin install $echo --activate
done < pluginfilepath

# Download from private git repository
bot "Je télécharge le thème WP0 theme :"
cd wp-content/themes/
git clone git@bitbucket.org:maximebj/wordpress-zero-theme.git
wp theme activate $1

# Create standard pages
bot "Je crée les pages habituelles (Accueil, blog, contact...)"
wp post create --post_type=page --post_title='Accueil' --post_status=publish
wp post create --post_type=page --post_title='Blog' --post_status=publish
wp post create --post_type=page --post_title='Contact' --post_status=publish
wp post create --post_type=page --post_title='Mentions Légales' --post_status=publish

# Create fake posts
bot "Je crée quelques faux articles"
curl http://loripsum.net/api/5 | wp post generate --post_content --count=5

# Change Homepage
bot "Je change la page d'accueil et la page des articles"
wp option update show_on_front page
wp option update page_on_front 3
wp option update page_for_posts 4

# Menu stuff
bot "Je crée le menu principal, assigne les pages, et je lie l'emplacement du thème : "
wp menu create "Menu Principal"
wp menu item add-post menu-principal 3
wp menu item add-post menu-principal 4
wp menu item add-post menu-principal 5
wp menu location assign menu-principal main-menu

# Misc cleanup
bot "Je supprime Hello Dolly, les thèmes de base et les articles exemples"
wp post delete 1 --force # Article exemple - no trash. Comment is also deleted
wp post delete 2 --force # page exemple
wp plugin delete hello
wp theme delete twentytwelve
wp theme delete twentythirteen
wp theme delete twentyfourteen
wp option update blogdescription ''

# Permalinks to /%postname%/
bot "J'active la structure des permaliens"
wp rewrite structure "/%postname%/" --hard
wp rewrite flush --hard

# cat and tag base update
wp option update category_base theme
wp option update tag_base sujet

# Git project
# REQUIRED : download Git at http://git-scm.com/downloads
bot "Je Git le projet :"
cd ../..
git init    # git project
git add -A  # Add all untracked files
git commit -m "Initial commit"   # Commit changes

# Open the stuff
bot "Je lance le navigateur, Sublime Text et le finder."

# Open in browser
open $url
open "${url}wp-admin"

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
echo "URL du site:   $url"
echo "Login admin :  admin$1"
echo "Password :  ${cyan}${bold} $password ${normal}${normal}"
echo
echo "${grey}(N'oubliez pas le mot de passe ! Je l'ai copié dans le presse-papier)${normal}"

echo
bot "à Bientôt !"
echo
echo
