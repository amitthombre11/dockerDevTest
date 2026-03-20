#!/bin/bash

backend=admin-build-repo
frontend=msbteWebAdminFront
branch=master

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}Changing directory to backend...${NC}"
cd $backend

echo "git checkout $branch"
git checkout $branch

cd ..

echo -e "${CYAN}Removing old index.html from backend...${NC}"
echo -e "rm -rf $backend/public/index.html"
rm -rf $backend/public/index.html

echo -e "${CYAN}Removing old assets folder from backend...${NC}"
echo -e "rm -rf $backend/public/assets"
rm -rf $backend/public/assets

echo -e "${CYAN}Removing old static folder from backend...${NC}"
echo -e "rm -rf $backend/public/static"
rm -rf $backend/public/static

echo -e "${CYAN}Removing build folder from frontend...${NC}"
echo -e "rm -rf $frontend/build"
rm -rf $frontend/build

echo -e "${CYAN}Changing directory to frontend...${NC}"
echo -e "cd $frontend"
cd $frontend

echo -e "${YELLOW}Building frontend...${NC}"
echo -e "npm run build"
npm run build

echo -e "${GREEN}Copying assets from frontend to backend...${NC}"
echo -e "cp -r build/assets ./../$backend/public/"
cp -r build/assets ./../$backend/public/

echo -e "${GREEN}Copying index.html from frontend to backend...${NC}"
echo -e "cp -r build/index.html ./../$backend/public/"
cp -r build/index.html ./../$backend/public/

echo -e "${GREEN}Copying static folder from frontend to backend...${NC}"
echo -e "cp -r build/static ./../$backend/public/"
cp -r build/static ./../$backend/public/

cd ..

cd $backend

pwd

echo -e "${CYAN}Adding changes to git...${NC}"
echo -e "git add ."
git add .

echo -e "${YELLOW}Checking git branch...${NC}"
echo -e "git branch"
git branch

echo -e "${GREEN}Committing changes...${NC}"
echo -e "git commit -m build"
git commit -m build

echo -e "${YELLOW}Pushing changes to origin $branch...${NC}"
echo -e "git push origin $branch"
git push origin $branch
