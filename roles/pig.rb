name 'pig'
description 'Installs pig with piggybank and extra jars.'

run_list %w[
  pig
  pig::install_from_package
  pig::link_extra_jars
  pig::piggybank
]
