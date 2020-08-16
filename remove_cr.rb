Dir.glob('*').each{|file| text= File.read(file).gsub("\r",""); File.open(file,'w'){|f|f<<text} }
