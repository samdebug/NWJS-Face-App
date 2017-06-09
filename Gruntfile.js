module.exports = function(grunt) {

  grunt.initConfig({
    copy: {
      src: {
        expand: true,
        cwd: './src/',
        src: '**',
        dest: './temp',
        filter: function(filepath) {
          var regex = /jade|coffee/;
          return !regex.test(filepath);
        }
      }
    },
    coffee: {
      src: {
        files: {
          './temp/js/application.js': ['./src/coffee/lang.coffee',
            './src/coffee/fattr.coffee', './src/coffee/rest.coffee',
            './src/coffee/util.coffee', './src/coffee/stor.coffee',
            './src/coffee/application.coffee', './src/coffee/ui-base.coffee',
            './src/coffee/ui-modal.coffee', './src/coffee/ui-page.coffee',
            './src/coffee/main.coffee'
          ]
        }
      }
    },
    jade: {
      index: {
        files: {
          './temp/index.html': './src/jade/index.jade'
        }
      },
      remained: {
        expand: true,
        flatten: true,
        cwd: './src/jade',
        src: ['*.jade'],
        dest: './temp/html/',
        ext: '.html',
        filter: function(filename) {
          var regex = /index/;
          return !regex.test(filename);
        }
      }
    },
    uglify: {
      release: {
        files: [{
          expand: true,
          cwd: './temp/js',
          src: '**/*.js',
          dest: './temp/js'
        }]
      }
    },
    clean: {
      options: {
        force: true
      },
      temp: ['./temp/*'],
      build: ['./build/*']
    },
    scp: {
      options: {
        host: '192.168.2.104',
        username: 'zonion',
        password: 'passwd'
      },
      src: {
        files: [{
          cwd: './temp/',
          src: '**/*',
          filter: 'isFile',
          dest: '/home/zonion/Documents/workspace/zexabox/zadmin/src'
        }]
      },
    },
    nodewebkit: {
      win: {
        options: {
          build_dir: './build',
          mac: false,
          win: true,
          linux32: false,
          linux64: false
        },
        src: './temp/**/*'
      },
      mac: {
        options: {
          build_dir: './build',
          mac_icns: './icon.icns',
          mac: true,
          win: false,
          linux32: false,
          linux64: false
        },
        src: './temp/**/*'
      },
      linux: {
        options: {
          build_dir: './build',
          mac: false,
          win: false,
          linux32: false,
          linux64: true
        },
        src: './temp/**/*'
      },
      all: {
        options: {
          build_dir: './build',
          mac_icns: './icon.icns',
          mac: false,
          win: true,
          linux32: false,
          linux64: false
        },
        src: './temp/**/*'
      }
    },
    zip_directories: {
      win: {
        files: [{
          filter: 'isDirectory',
          expand: true,
          cwd: './build/releases/Zadmin/win',
          src: ['*'],
          dest: './pack/win'
        }]
      }
    }
  });

  grunt.loadNpmTasks('grunt-contrib-coffee');
  grunt.loadNpmTasks('grunt-contrib-jade');
  grunt.loadNpmTasks('grunt-contrib-clean');
  grunt.loadNpmTasks('grunt-contrib-copy');
  grunt.loadNpmTasks('grunt-contrib-uglify');
  grunt.loadNpmTasks('grunt-node-webkit-builder');
  grunt.loadNpmTasks('grunt-zip-directories');
  grunt.loadNpmTasks('grunt-scp');

  grunt.registerTask('default', ['copy:src',
    'coffee:src', 'jade:index',
    'jade:remained', 'nodewebkit:all',
    'clean:temp'
  ]);
  grunt.registerTask('debug', ['copy:src',
    'coffee:src',
    'jade:index', 'jade:remained',
    'nodewebkit:all', 'clean:temp'
  ]);
  grunt.registerTask('release', ['copy:src',
    'coffee:src', 'jade:index',
    'jade:remained', 'uglify:release',
    'nodewebkit:all', 'clean:temp',
    'zip_directories:win'
  ]);
  grunt.registerTask('win', ['copy:src',
    'coffee:src', 'jade:index',
    'jade:remained', 'nodewebkit:win',
    'clean:temp'
  ]);
  grunt.registerTask('mac', ['copy:src',
    'coffee:src', 'jade:index',
    'jade:remained', 'nodewebkit:mac',
    'clean:temp'
  ]);
  grunt.registerTask('linux', ['copy:src',
    'coffee:src', 'jade:index',
    'jade:remained', 'nodewebkit:linux',
    'clean:temp'
  ]);
  grunt.registerTask('compile', ['copy:src',
    'coffee:src',
    'jade:index', 'jade:remained'
  ]);
  grunt.registerTask('cleanup', ['clean:temp', 'clean:build']);
  grunt.registerTask('deploy', ['copy:src',
    'coffee:src', 'jade:index',
    'jade:remained', 'uglify:release',
    'scp:src', 'clean:temp'
  ]);

};
