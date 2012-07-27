#Using Polyrex with embedded YAML

    require 'polyrex'

    polyrex = Polyrex.new
    polyrex.parse File.read('/tmp/px220712T1426.txt')
    puts polyrex.to_xml pretty: true

    polyrex.records[0].commands
    #=> [{"s1"=>"rvm", "s2"=>"sudo rvm"}, {"s1"=>"rvm2", "s2"=>"sudo rvm2"}]

    polyrex.find_by_machine_title('toni').storage
    #=> ["/", "/media/usb1"]

file px220712T1426.txt:

    <?polyrex schema="entries[title,tags,desc]/machine[title]"?>
    title: Machines used for remote SSH commands
    tags: ssh remote machine
    desc: s1 is substituted with s2

    amadora
      commands ---
        - {s1: rvm, s2: sudo rvm}  
        - {s1: rvm2, s2: sudo rvm2}      
    lucia
    toni
      commands ---
        - {s1: rvm, s2: /home/james/.rvm/bin/rvm}
      storage ---
        [/, /media/usb1]
    niko
      commands ---
        - {s1: rvm, s2: /home/james/.rvm/bin/rvm}
