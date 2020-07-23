module.exports = (grunt) ->
  require('load-grunt-tasks')(grunt)
  grunt.loadNpmTasks('grunt1.0-dom-munger') # the naming convention of the package does not allow auto-discovery.

  `const sass = require('node-sass')`

  grunt.initConfig
    pkg: grunt.file.readJSON('package.json')
    version_tag: 'v<%= pkg.version %>'
    comments: """
/*!
Chosen, a Select Box Enhancer for jQuery and Prototype
by Patrick Filler for Harvest, http://getharvest.com

Version <%= pkg.version %>
Full source at https://github.com/harvesthq/chosen
Copyright (c) 2011-<%= grunt.template.today('yyyy') %> Harvest http://getharvest.com

MIT License, https://github.com/harvesthq/chosen/blob/master/LICENSE.md
This file is generated by `grunt build`, do not edit it by hand.
*/
\n
"""
    minified_comments: "/* Chosen <%= version_tag %> | (c) 2011-<%= grunt.template.today('yyyy') %> by Harvest | MIT License, https://github.com/harvesthq/chosen/blob/master/LICENSE.md */\n"

    concat:
      options:
        banner: '<%= comments %>'
      jquery:
        src: ['public/chosen.jquery.js']
        dest: 'public/chosen.jquery.js'
      proto:
        src: ['public/chosen.proto.js']
        dest: 'public/chosen.proto.js'
      css:
        src: ['public/chosen.css']
        dest: 'public/chosen.css'

    copy:
      main:
        src: 'LICENSE.md'
        dest: 'public/'
      php:
        src: 'composer.json'
        dest: 'public/'

    coffee:
      options:
        join: true
      jquery:
        files:
          'public/chosen.jquery.js': ['coffee/lib/select-parser.coffee', 'coffee/lib/abstract-chosen.coffee', 'coffee/chosen.jquery.coffee']
      proto:
        files:
          'public/chosen.proto.js': ['coffee/lib/select-parser.coffee', 'coffee/lib/abstract-chosen.coffee', 'coffee/chosen.proto.coffee']
      test:
        files:
          'spec/public/jquery_specs.js': 'spec/jquery/*.spec.coffee'
          'spec/public/proto_specs.js': 'spec/proto/*.spec.coffee'

    uglify:
      options:
        banner: '<%= minified_comments %>'
      jquery:
        options:
          ie8: true
          mangle:
            reserved: ['jQuery']
        files:
          'public/chosen.jquery.min.js': ['public/chosen.jquery.js']
      proto:
        files:
          'public/chosen.proto.min.js': ['public/chosen.proto.js']

    sass:
      options:
        outputStyle: 'expanded'
        implementation: sass
      chosen_css:
        files:
          'public/chosen.css': 'sass/chosen.scss'

    postcss:
      options:
        processors: [
          require('autoprefixer')(browsers: 'last 2 versions, IE 8')
        ]
      main:
        src: 'public/chosen.css'

    cssmin:
      options:
        banner: '<%= minified_comments %>'
        keepSpecialComments: 0
      main:
        src: 'public/chosen.css'
        dest: 'public/chosen.min.css'

    watch:
      default:
        files: ['coffee/**/*.coffee', 'sass/*.scss']
        tasks: ['build', 'jasmine']
      test:
        files: ['spec/**/*.coffee']
        tasks: ['jasmine']

    jasmine:
      jquery:
        options:
          vendor: [
            'public/docsupport/jquery-3.2.1.min.js'
          ]
          specs: 'spec/public/jquery_specs.js'
        src: [ 'public/chosen.jquery.js' ]
      jquery_old:
        options:
          vendor: [
            'public/docsupport/jquery-1.12.4.min.js'
          ]
          specs: 'spec/public/jquery_specs.js'
        src: [ 'public/chosen.jquery.js' ]
      proto:
        options:
          vendor: [
            'public/docsupport/prototype-1.7.0.0.js'
            'node_modules/simulant/dist/simulant.umd.js'
          ]
          specs: 'spec/public/proto_specs.js'
        src: [ 'public/chosen.proto.js' ]

  grunt.loadTasks 'tasks'

  grunt.registerTask 'default', ['build']
  grunt.registerTask 'build', ['coffee:jquery', 'coffee:proto', 'sass', 'concat', 'uglify', 'postcss', 'cssmin', 'copy']
  grunt.registerTask 'test',  ['coffee', 'jasmine']
  grunt.registerTask 'test:jquery',  ['coffee:test', 'coffee:jquery', 'jasmine:jquery', 'jasmine:jquery_old']
  grunt.registerTask 'test:proto',  ['coffee:test', 'coffee:proto', 'jasmine:proto']


