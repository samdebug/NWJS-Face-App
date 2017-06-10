Node-Webkit 自动化打包
====================

### 安装要求

1. Node.js
2. Grunt-CLI

### 平台搭建

1. 安装Node.js
2. 安装Grunt, `npm install -g grunt-cli`
3. 拉取本Repo, `git clone `
4. 拉取Zadmin, `git clone git@bitbucket.org:zexabox/zadmin.git src`
5. 安装相应的依赖包, `npm install`
6. 依赖包 `grunt-contrib-clean`, `grunt-contrib-coffee`, `grunt-contrib-copy`, `grunt-contrib-jade`, `grunt-contrib-uglify`, `grunt-node-webkit-builder`, `grunt-scp`, `grunt-zip-directories`

### 构建APP

在完成平台搭建后，输入`grunt`即可自动打包APP
