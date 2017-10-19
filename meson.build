project('PrayTime', 'vala', 'c')

glib_dep      = dependency('glib-2.0')
gobject_dep   = dependency('gobject-2.0')
gio_dep       = dependency('gio-2.0')
json_dep      = dependency('json-glib-1.0')
gstreamer_dep = dependency('gstreamer-1.0')

version       = '0.2.2'
bindir        = join_paths(get_option('prefix'), get_option('bindir'))
datadir       = join_paths(get_option('prefix'), get_option('datadir'), 'praytime')

conf          = configuration_data()
conf.set('VERSION'     , version)
conf.set('INSTALL_PATH', bindir)
conf.set('DATA_PATH'   , datadir)

sources       = [
    'src/Pluie.PrayTime.vala',
    'build/main.vala'
]

configure_file(
  input: 'main.vala.in',
  output: 'main.vala',
  configuration: conf
)

install_data('config/praytime.ini', install_dir : datadir)

executable('praytime', sources, install : true, install_dir : bindir,
           dependencies : [glib_dep, gobject_dep, gio_dep, json_dep, gstreamer_dep])

