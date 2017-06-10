class ResSource
    constructor: (@rest, @process) ->
        @items = []
        @map   = {}

    update: () =>
        @rest.list().done (data) =>
            if data.status == "success"
                @_update_data data.detail
            else
                @_update_data []
        .fail (jqXHR, text_status, e) =>
            @_update_data []

    get: (id) => @map[id]
        
    _update_data: (data) =>
        if @process
            data = @process(data)
        @items = data
        @map = {}
        for o in @items
            @map[o.id] = o
        @notify_updated()

    notify_updated: () =>
        $(this).triggerHandler "updated", this

class SingleSource
    constructor: (@rest, @default) ->
        @data = @default

    update: () =>
        @rest.query().done (data) =>
            if data.status == "success"
                @data = data.detail
            else
                @data = @default
            @notify_updated()
        .fail (jqXHR, text_status, e) =>
            @data = @default
            @notify_updated()

    notify_updated: () =>
        $(this).triggerHandler "updated", this

class Chain
    constructor: (@errc) ->
        @dfd = $.Deferred()
        @chains = []
        @total = 0

    chain: (arg) =>
        if arg instanceof Chain
            queue = arg.chains
        else if $.isArray arg
            queue = arg
        else
            queue = [arg]
        for step in queue
            @chains.push step
            @total += 1
        return this

    _notify_progress: () =>
        $(this).triggerHandler "progress", ratio: (@total-@chains.length)/@total

    _done: (data, text_status, jqXHR) =>
        if @chains.length == 0
            $(this).triggerHandler "completed"
            temp_data.push data
            @dfd.resolve()
        else
            [@cur, @chains...] = @chains
            jqXHR = @cur()
            @_notify_progress()
            jqXHR.done(@_done).fail(@_fail)

    _fail: (jqXHR, text_status, e) =>
        reason = if jqXHR.status == 400 then JSON.parse(jqXHR.responseText) else text_status
        $(this).triggerHandler "error", error: reason, step: @cur
        if @errc
            @errc error: reason, step: @cur
            @_done()
        else
            @dfd.reject jqXHR.status, reason

    execute: () =>
        @_done()
        @promise = @dfd.promise()
        @promise

class StorageData
    constructor: (@host) ->
        @_update_queue = []
        @_deps =
           disks: ["disks", "raids", "journals"]
           raids: ["disks", "raids", "journals"]
           volumes: ["raids", "volumes", "initrs", "journals"]
           initrs: ["volumes", "initrs", "journals"]
           networks: ["networks", "gateway", "journals"]
           monfs: ["monfs", "volumes", "journals"]
           filesystem: ["filesystem", "volumes", "journals"]
           all: ["dsus", "disks", "raids", "volumes", "initrs", "networks", "journals", "gateway", "filesystem", "systeminfo"]


        @disks = new ResSource(new DiskRest(@host))
        @raids = new ResSource(new RaidRest(@host))
        @volumes = new ResSource(new VolumeRest(@host))
        @initrs = new ResSource(new InitiatorRest(@host))
        @networks = new ResSource(new NetworkRest(@host))
        @journals = new ResSource(new JournalRest(@host))
        @dsus = new ResSource(new DSURest(@host))
        
        @gateway = new SingleSource(new GatewayRest(@host), ipaddr: "")
        @monfs = new SingleSource(new MonFSRest(@host), {})
        @filesystem = new SingleSource(new FileSystemRest(@host), {})
        @systeminfo = new SingleSource(new SystemInfoRest(@host), version: "UNKOWN")

        
        @stats = items: []
        @socket_statist = io.connect "#{@host}/statistics", {
            "reconnect": false,
            "force new connection": true
        }
        @socket_statist.on "statistics", (data) =>               #get read_mb and write_mb
            if @stats.items.length > 120
                @stats.items.shift()
            @stats.items.push(data)
            $(@stats).triggerHandler "updated", @stats

        @socket_event = io.connect "#{@host}/event", {
            "reconnect": false,
            "force new connection": true
        }
        @socket_event.on "event", @feed_event
        @socket_event.on "disconnect", @disconnect_listener
        @_update_loop()


    raid_disks: (raid) =>
        disks = (d for d in @disks.items when d.raid == raid.name)
        disks.sort (o1,o2) -> o1.slot - o2.slot
        return disks

    volume_initrs: (volume) =>
        (initr for initr in @initrs.items when volume.name in (v for v in initr.volumes))

    initr_volumes: (initr) =>
        (v for v in @volumes.items when v.name in initr.volumes)

    spare_volumes: () =>
        used = []
        for initr in @initrs.items
            used = used.concat(initr.volumes)
        volume for volume in @volumes.items when volume.name not in used

    feed_event: (e) =>
        console.log e
        switch e.event
            when "disk.ioerror", "disk.formated", "disk.plugged", "disk.unplugged"
                @_update_queue.push @disks
                @_update_queue.push @journals
            when "disk.role_changed"
                @_update_queue.push @disks
                @_update_queue.push @raids
                @_update_queue.push @journals
            when "raid.normal", "raid.degraded", "raid.failed"
                @_update_queue.push @raids
                @_update_queue.push @journals
            when "raid.rebuild"
                raid = @raids.get e.raid
                if raid != undefined
                    raid.rebuilding = e.rebuilding
                    raid.health = e.health
                    raid.rebuild_progress = e.rebuild_progress
                    $(this).triggerHandler "raid", raid
            when "raid.rebuild_done"
                raid = @raids.get e.raid
                if raid != undefined
                    raid.rebuilding = e.rebuilding
                    raid.health = e.health
                    raid.rebuild_progress = e.rebuild_progress
                    $(this).triggerHandler "raid", raid
                    @_update_queue.push @disks
            when "raid.created", "raid.removed"           
                @_update_queue.push @disks
                @_update_queue.push @raids
                @_update_queue.push @journals
            when "raid.rqr"
                raid = @raids.get e.raid
                raid.rqr_count = e.rqr_count
                $(this).triggerHandler "raid", raid
            when "volume.failed", "volume.normal"
                volume = @volumes.get e.uuid
                if volume != undefined
                    volume.event = e.event
                    $(this).triggerHandler "volume", volume
                    @_update_queue.push @volumes
                    @_update_queue.push @journals
            when "volume.created"         
                @_update_queue.push @volumes
                @_update_queue.push @raids
                @_update_queue.push @journals
                volume = event : e.event
                $(this).triggerHandler "volume", volume
                #volume = sync:e.sync, sync_progress: e.sync_progress, id: e.uuid
                #$(this).triggerHandler "volume", volume
            when "volume.removed"
                @_update_queue.push @volumes
                @_update_queue.push @raids
                @_update_queue.push @journals
            when "volume.sync"
                volume = @volumes.get e.lun
                if volume != undefined
                    volume.sync_progress = e.sync_progress
                    volume.syncing = e.syncing
                    volume.event = e.event
                    $(this).triggerHandler "volume", volume
            when "volume.syncing"
                volume = @volumes.get e.lun
                if volume != undefined
                    volume.sync_progress = e.sync_progress
                    volume.syncing = e.syncing
                    volume.event = e.event
                    $(this).triggerHandler "volume", volume                
            when "volume.sync_done"
                volume = @volumes.get e.lun
                if volume != undefined
                    volume.sync_progress = e.sync_progress
                    volume.syncing = e.syncing
                    volume.event = e.event
                    $(this).triggerHandler "volume", volume
            when "initiator.created", "initiator.removed"
                @_update_queue.push @initrs
                @_update_queue.push @journals
            when "initiator.session_change"
                initr = @initrs.get e.initiator
                initr.active_session = e.session
                $(this).triggerHandler "initr", initr
            when "vi.mapped", "vi.unmapped"
                @_update_queue.push @initrs
                @_update_queue.push @volumes
                @_update_queue.push @journals
            when "monfs.created", "monfs.removed"
                @_update_queue.push @monfs
                @_update_queue.push @volumes
                @_update_queue.push @journals
            when "fs.created", "fs.removed"
                @_update_queue.push @filesystem
                @_update_queue.push @volumes
                @_update_queue.push @journals
            when "notification"
                $(this).triggerHandler "notification", e
            when "user.login"
                $(this).triggerHandler "user_login", e.login_id
            
    update: (res, errc) =>
        chain = new Chain errc
        chain.chain(($.map @_deps[res], (name) => (=> this[name].update())))
        chain

    _update_loop: =>
        @_looper_id = setInterval((=>
            @_update_queue = unique @_update_queue
            @_update_queue[0].update?() if @_update_queue[0]?
            @_update_queue = @_update_queue[1...]
            return
            ), 1000)

    close_socket: =>
        @socket_event.disconnect()
        @socket_statist.disconnect()
        clearInterval @_looper_id if @_looper_id?
        return

    disconnect_listener: =>
        $(this).triggerHandler "disconnect", @host

class CentralStorageData
    constructor: (@host,@user) ->
        @_update_queue = []
        @_deps =
           ###
           centers: ["centers", "journals"]
           clouds: ["clouds", "journals"]
           machinedetails:['machinedetails','journals']
           warnings: ["warnings", "journals"]
           emails: ["emails", "journals"]
           stores: ["stores", "journals"]
           disks: ["disks", "raids", "journals"]
           raids: ["disks", "raids", "journals"]
           volumes: ["raids", "volumes", "initrs", "journals"]
           initrs: ["volumes", "initrs", "journals"]
           networks: ["networks", "gateway", "journals"]
           monfs: ["monfs", "volumes", "journals"]
           filesystem: ["filesystem", "volumes", "journals"]
           #all: ["centers", "networks", "journals", "gateway", "filesystem", "systeminfo"]
           #all: ["centers","clouds","stores","warnings","emails","machinedetails","journals"]###

           register: ["register"]
           pay: ["pay"]
           manager: ["manager"]
           #avatar : ["avatar"]
           all: ["register","pay","manager"]
        
        @register = new ResSource(new RegisterRest(@host,@user))
        @pay = new ResSource(new PayRest(@host,@user))
        @manager = new ResSource(new ManagerRest(@host,@user))

        #@avatar = new ResSource(new HeadRest(@host,@user))

        ###@centers = new ResSource(new CenterRest(@host))
        @clouds = new ResSource(new CloudRest(@host))
        @stores = new ResSource(new StoreRest(@host))
        @journals = new ResSource(new JournalRest(@host))
        @warnings = new ResSource(new WarningRest(@host))
        @emails = new ResSource(new EmailRest(@host))
        @machinedetails = new ResSource(new MachineDetailRest(@host))###
        @stats = items: []
        
        port1 = @host.split(':')[0] + ':5000'
        
        ###@socket_statist = io.connect "#{port1}/statistics", {
            "reconnect": false,
            "force new connection": true
        }
        
        @socket_statist.on "statistics", (data) =>
            return
            console.log data
            if @stats.items.length > 120
                @stats.items.shift()
            try
                datas = @_data(data)
                @stats.items.push(datas)
                $(@stats).triggerHandler "updated", @stats
            catch e
                return
        port2 = @host.split(':')[0] + ':8012'
        @socket_event = io.connect "#{port2}/event", {
            "reconnect": false,
            "force new connection": true
        }
        @socket_event.on "event", @feed_event
        @socket_event.on "disconnect", @disconnect_listener###
        
        #websocket
        @ws_port = @host.split(':')[0] + ':8080'
        @ws = new WebSocket('ws://' + @ws_port + '/ws/join?uname=' + @user);
        @ws.onmessage = @ws_feed_event

        @_update_loop()
    
    _data: (data) =>
        try
            socket_data = {}
            for i in ['server_cpu','server_mem','server_cache','store_cpu', \
                      'store_mem','store_cache','server_receive','server_sent', \
                      "store_net_write", "store_net_read", "store_vol_write", \
                      "store_vol_read","break_number", "raid_number", "volume_number", "disk_number", \
                      "store_system","store_cap","server_system","server_cap","temp","server_net_write", \
                      "server_net_read", "server_vol_write","server_vol_read","storages","exports","store_cap_total",'store_cap_remain']
                      
                socket_data[i] = 0

            if data.exports.length
                for i in data.exports
                    socket_data['server_cpu'] = socket_data['server_cpu'] + i.info[i.info.length - 1].cpu
                    socket_data['server_mem'] = socket_data['server_mem'] + i.info[i.info.length - 1].mem
                    socket_data['server_net_write'] = socket_data['server_net_write'] + i.info[i.info.length - 1].write_mb
                    socket_data['server_net_read'] = socket_data['server_net_read'] + i.info[i.info.length - 1].read_mb
                    socket_data['server_system'] = socket_data['server_system'] + i.info[i.info.length - 1].df[0].used_per
                    
                socket_data['server_cpu'] = (socket_data['server_cpu']/data.exports.length) + (Math.random())*2
                socket_data['server_mem'] = (socket_data['server_mem']/data.exports.length) + (Math.random())*2
                socket_data['server_vol_write'] = 0
                socket_data['server_vol_read'] = 0
                socket_data['server_cache'] = 0
                socket_data['server_cap'] = 0
                socket_data["exports"] = data.exports
                
            if data.storages.length
                for i in data.storages
                    socket_data['store_cpu'] = socket_data['store_cpu'] + i.info[i.info.length - 1].cpu
                    socket_data['store_mem'] = socket_data['store_mem'] + i.info[i.info.length - 1].mem
                    socket_data['temp'] = socket_data['temp'] + i.info[i.info.length - 1].temp
                    socket_data['store_net_write'] = socket_data['store_net_write'] + i.info[i.info.length - 1].write_mb
                    socket_data['store_net_read'] = socket_data['store_net_read'] + i.info[i.info.length - 1].read_mb
                    socket_data['store_vol_write'] = socket_data['store_vol_write'] + i.info[i.info.length - 1].write_vol
                    socket_data['store_vol_read'] = socket_data['store_vol_read'] + i.info[i.info.length - 1].read_vol
                    if i.info[i.info.length - 1].cache_total isnt 0
                        socket_data['store_cache'] = socket_data['store_cache'] + i.info[i.info.length - 1].cache_used/i.info[i.info.length - 1].cache_total
                    if i.info[i.info.length - 1].df.length is 2
                        socket_data['store_system'] = socket_data['store_system'] + i.info[i.info.length - 1].df[0].used_per
                        socket_data['store_cap'] = socket_data['store_cap'] + i.info[i.info.length - 1].df[1].used_per
                        socket_data['store_cap_total'] = socket_data['store_cap_total'] + i.info[i.info.length - 1].df[1].total
                        socket_data['store_cap_remain'] = socket_data['store_cap_remain'] + i.info[i.info.length - 1].df[1].available
                    else
                        socket_data['store_system'] = socket_data['store_system'] + i.info[i.info.length - 1].df[0].used_per
                socket_data['store_cpu'] = (socket_data['store_cpu']/data.storages.length) + (Math.random())*2
                socket_data['store_mem'] = (socket_data['store_mem']/data.storages.length) + (Math.random())*2
                socket_data['store_cache'] = socket_data['store_cache']/data.storages.length
                socket_data['store_system'] = socket_data['store_system']/data.storages.length
                socket_data['store_cap'] = socket_data['store_cap']/data.storages.length
                socket_data['temp'] = (socket_data['temp']/data.storages.length) + (Math.random())*5
                socket_data['storages'] = data.storages
            socket_data
        catch e
            socket_data
            console.log e
            
    server_stores: (server) =>
        store = []
        ((store.push {"node":i.cid,"ip":i.ip,"location":i.sid}) for i in @clouds.items when i.export is server.ip and i.cid isnt 0)
        store
        
    store_servers:(store) =>
        [{"ip":store.export}]

    ws_feed_event: (e) =>
        data = JSON.parse(event.data)
        console.log(data);
        #if data.confidence is "0"
        #    return
        switch data.name
            when "compareResult"
                $(this).triggerHandler "compareresult", data
            when "user.login"
                $(this).triggerHandler "user_login", data

    feed_event: (e) =>
        return
        console.log e
        events = ["disk.plugged","disk.unplugged","raid.created","volume.created", \
                       "volume.removed","raid.removed","raid.failed","volume.failed","raid.degraded"]
        ###switch e.event
            when "ping.offline"
                @_tooltips(e.ip,"掉线了")
                @_update_queue.push @centers
                @_update_queue.push @journals
                @_update_queue.push @stores
                @_update_queue.push @stats
                @_update_queue.push @machinedetails
            when "ping.online"
                @_tooltips(e.ip,"上线了")
                @_update_queue.push @centers
                @_update_queue.push @journals
                @_update_queue.push @stores
                @_update_queue.push @stats
                @_update_queue.push @machinedetails
            when "disk.unplugged"
                @_tooltips(e.ip,"掉盘了")
                @_update_queue.push @centers
                @_update_queue.push @journals
                @_update_queue.push @stores
                @_update_queue.push @stats
                @_update_queue.push @machinedetails

            when "raid.degraded", "raid.failed"
                @_tooltips(e.ip,"有阵列损坏")
                @_update_queue.push @centers
                @_update_queue.push @journals
                @_update_queue.push @stores
                @_update_queue.push @stats
                @_update_queue.push @machinedetails
            when "volume.failed"
                @_tooltips("e.ip","有虚拟磁盘损坏")
                @_update_queue.push @centers
                @_update_queue.push @journals
                @_update_queue.push @stores
                @_update_queue.push @stats
                @_update_queue.push @machinedetails
            when "databox.created"
                @_tooltips("","进入保险箱模式")
                @_update_queue.push @centers
                @_update_queue.push @journals
                @_update_queue.push @stores
                @_update_queue.push @stats
                @_update_queue.push @machinedetails
             
            
            when "raid.created","volume.created", "volume.removed","raid.removed"
                @_update_queue.push @centers
                @_update_queue.push @journals
                @_update_queue.push @stores
                @_update_queue.push @stats
                @_update_queue.push @machinedetails
            when "disk.ioerror", "disk.formated", "disk.plugged"
                @_update_queue.push @centers
                @_update_queue.push @journals
                @_update_queue.push @stores
                @_update_queue.push @stats
                @_update_queue.push @disks
                @_update_queue.push @machinedetails
            when "disk.role_changed"
                @_update_queue.push @disks
                @_update_queue.push @raids
                @_update_queue.push @journals
                @_update_queue.push @machinedetails
            when "raid.normal"
                @_update_queue.push @raids
                @_update_queue.push @journals
                @_update_queue.push @machinedetails

            when "raid.rebuild"
                raid = @raids.get e.raid
                if raid != undefined
                    raid.rebuilding = e.rebuilding
                    raid.health = e.health
                    raid.rebuild_progress = e.rebuild_progress
                    $(this).triggerHandler "raid", raid 
            when "raid.rebuild_done"
                raid = @raids.get e.raid
                if raid != undefined
                    raid.rebuilding = e.rebuilding
                    raid.health = e.health
                    raid.rebuild_progress = e.rebuild_progress
                    $(this).triggerHandler "raid", raid
                    @_update_queue.push @disks
            when "raid.created", "raid.removed"           
                @_update_queue.push @disks
                @_update_queue.push @raids
                @_update_queue.push @journals
            when "raid.rqr"
                raid = @raids.get e.raid
                raid.rqr_count = e.rqr_count
                $(this).triggerHandler "raid", raid
            when "notification"
                $(this).triggerHandler "notification", e
            when "user.login"
                $(this).triggerHandler "user_login", e.login_id###
                
    _tooltips:(ip,type) =>
        $(`function(){
            $.extend($.gritter.options, {
                class_name: 'gritter', 
                position: 'bottom-right', 
                fade_in_speed: 100, 
                fade_out_speed: 100, 
                time: 30000 
            });
            $.gritter.add({
                title: '<i class="icon-bell">告警信息</i>',
                text: '<a href="#" style="color:#ccc;font-size:14px;">' + ip + type + '</a><br>已发送邮件告警.'
            });
            return false;
        }`)
    
    update: (res, errc) =>
        chain = new Chain errc
        chain.chain(($.map @_deps[res], (name) => (=> this[name].update())))
        chain

    _update_loop: =>
        @_looper_id = setInterval((=>
            @_update_queue = unique @_update_queue
            @_update_queue[0].update?() if @_update_queue[0]?
            @_update_queue = @_update_queue[1...]
            return
            ), 1000)

    close_socket: =>
        try
            #@socket_event.disconnect()
            #@socket_statist.disconnect()
            @ws.close()
            clearInterval @_looper_id if @_looper_id?
            #NProgress.start()
            #setTimeout (=> NProgress.done();$('.fade').removeClass('out')),100
            $(".page-content").css("background-color","#364150")
            $('.menu-toggler').attr('style', 'display:none')
            $('.navbar-fixed-top').attr('style', 'display:none')

            if $('body').hasClass("page-sidebar-closed")
                $('body').removeClass("page-sidebar-closed")
            return
        catch e
            return

    disconnect_listener: =>
        $(this).triggerHandler "disconnect", @host

this.Chain = Chain
this.StorageData = StorageData
this.CentralStorageData = CentralStorageData