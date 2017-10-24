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

# Plugins : path to plugins.txt
pluginfilepath="$PWD/plugins.txt" # "$PWD" = same folder as wippy.sh

# Menu tree : path to tree.txt
wp_tree_file="$PWD/tree.txt" # "$PWD" = same folder as wippy.sh

# Theme : WordPress slug theme name ("twentysixteen"), path to a ZIP file or git URL ("git@github.com:…")
# wp_theme="git@github.com:Fruitfulcode/Fruitful.git"
wp_theme="Fruitful"

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
sql_cmd=`mysql -u $db_user -p$db_password --skip-column-names -e "SHOW DATABASES LIKE '$db_name'"`
if [ "$sql_cmd" == "$db_name" ]; then
  sql_query="SELECT count(*) FROM information_schema.tables WHERE table_type = 'BASE TABLE' AND table_schema = '$db_name'"
  sql_cmd2=`mysql -u $db_user -p$db_password --skip-column-names -e "$sql_query"`
  if [ "$sql_cmd2" == 0 ]; then
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
# Copy password in clipboard
echo $password | pbcopy
bot "J'ai copié le mot de passe ${cyan}$password${normal} dans le presse-papier !"

# Plugins install
bot "J'installe les plugins à partir de la liste des plugins…"
while IFS=$' \t\n\r' read -r plugin  || [ -n "$plugin" ] # Fix Posix ignored last line
do
  # Ignore comments and new linebreaks
  if [[ $plugin != \#* ]] && [ -n "$plugin" ]; then
    wp plugin install $plugin --activate
  fi 
done < $pluginfilepath

# Download and install WordPress theme
bot "Je télécharge le thème désiré…"
if [[ $wp_theme =~ ^git@* ]] && git ls-remote $wp_theme &> /dev/null; then
  cd wp-content/themes/
  git clone $wp_theme
  wp_theme_name=`basename $wp_theme .git`
  wp theme activate $wp_theme_name
else
  wp theme install $wp_theme --activate 
fi

# Misc cleanup
bot "Je supprime Hello Dolly, les thèmes de base et les articles exemples…"
wp post delete 1 --force # Article exemple - no trash. Comment is also deleted
wp post delete 2 --force # Page exemple
wp plugin delete hello
wp theme delete twentyfifteen
wp theme delete twentysixteen
wp theme delete twentyseventeen
wp option update blogdescription "$2"

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
        tree_line_trim="${tree_line//&/}"
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
bot "Je change la page d'accueil et la page des articles…"
wp option update show_on_front page # A static page as homepage. Default : latest posts
wp option update page_for_posts 4 # Page ID that displays posts (blog)
wp option update category_base theme # Default category base for categories permalink
wp option update tag_base sujet # Default tag base for tags permalink

# Permalinks to /%postname%/
bot "J'active la structure des permaliens…"
wp rewrite structure "/%postname%/" --hard
wp rewrite flush --hard

# Git project
if type git &> /dev/null; then
  bot "Je versionnne le projet avec Git…"
  cd $pathtoinstall
  git init # Init a git project
  git add -A # Add all untracked files
  git commit --quiet -m "Initial commit" # Commit changes
  echo "         Projet versionné avec succès."
fi

# Open the stuff
# bot "Je lance le navigateur, Sublime Text et le finder…"

# Open in browser
# open $url
# open "${wp_url}wp-admin"

# Open in Sublime text
# REQUIRED : activate subl alias at https://www.sublimetext.com/docs/3/osx_command_line.html
# cd wp-content/themes
# subl $1

# Open in finder
# cd $1
# open .

# That's all ! Install summary
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
