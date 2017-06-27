class Page extends AvalonTemplUI
    constructor: (prefix, src, attr={}) ->
        super prefix, src, ".page-content", true, attr
        

class DetailTablePage extends Page
    constructor: (prefix, src) ->
        super prefix, src

    detail: (e) =>
        if not @has_rendered
            return
        tr = $(e.target).parents("tr")[0]
        res = e.target.$vmodel.$model.e
        if @data_table.fnIsOpen tr
            $("div", $(tr).next()[0]).slideUp =>
                @data_table.fnClose tr
                res.detail_closed = true
                close_detial? res
                delete avalon.vmodels[res.id]
        else
            try
                res.detail_closed = false
                console.log res
                [html,vm] = @detail_html res
                row = @data_table.fnOpen tr, html, "details"
                avalon.scan row, vm
                $("div", row).slideDown()
            catch e
                console.log e

class OverviewPage extends Page
    constructor: (@sd, @switch_to_page) ->
        super "overviewpage-", "html/overviewpage.html"
        @flow_max = 0

        $(@sd.disks).on "updated", (e, source) =>
            disks = []
            
            for i in source.items
                if i.health == "normal"
                    disks.push i
            @vm.disk_num = disks.length
        $(@sd.raids).on "updated", (e, source) =>
            @vm.raid_num = source.items.length
        $(@sd.volumes).on "updated", (e, source) =>
            @vm.volume_num = source.items.length
        $(@sd.initrs).on "updated", (e, source) =>
            @vm.initr_num = source.items.length

        $(@sd.stats).on "updated", (e, source) =>
            if @has_rendered
                latest = source.items[source.items.length-1]
                @vm.cpu_load  = parseInt latest.cpu
                @vm.mem_load  = parseInt latest.mem
                @vm.temp_load = parseInt latest.temp
                @refresh_flow()

        $(@sd.journals).on "updated", (e, source) =>
            @vm.journals = @add_time_to_journal source.items[..]

    define_vm: (vm) =>
        vm.lang = lang.overviewpage
        vm.disk_num = 0
        vm.raid_num = 0
        vm.volume_num = 0
        vm.initr_num = 0
        vm.cpu_load = 0
        vm.mem_load = 0
        vm.temp_load = 0
        vm.journals = []
        vm.flow_type = "fwrite_mb"
        vm.rendered = @rendered

        vm.switch_flow_type = (e) =>
            v = $(e.target).data("flow-type")                 #make sure to show fread_mb or fwrite_mb
            vm.flow_type = v
            @flow_max = 0
        vm.switch_to_page = @switch_to_page
        
        vm.$watch "cpu_load", (nval, oval) =>
            $("#cpu-load").data("easyPieChart").update?(nval) if @has_rendered
            return
        vm.$watch "mem_load", (nval, oval) =>
            $("#mem-load").data("easyPieChart").update?(nval) if @has_rendered
            return
        vm.$watch "temp_load", (nval, oval) =>
            $("#temp-load").data("easyPieChart").update?(nval) if @has_rendered
            return
        
    rendered: () =>
        super()
        opt = animate: 1000, size: 128, lineWidth: 10, lineCap: "butt", barColor: ""
        opt.barColor = App.getLayoutColorCode "green"
        $("#cpu-load").easyPieChart opt
        $("#cpu-load").data("easyPieChart").update? @vm.cpu_load
        $("#mem-load").easyPieChart opt
        $("#mem-load").data("easyPieChart").update? @vm.mem_load
        $("#temp-load").easyPieChart opt
        $("#temp-load").data("easyPieChart").update? @vm.temp_load

        $scroller = $("#journals-scroller")
        $scroller.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: false

        [max, ticks] = @flow_data_opt()
        @plot_flow max, ticks

    flow_data_opt: () =>
        type = @flow_type()
        #type = @vm.flow_type
        #other_type = @combine_type()
        #flow_peak = Math.max(((sample[type] + sample[other_type]) for sample in @sd.stats.items)...)
        flow_peak = Math.max((sample[type] for sample in @sd.stats.items)...)
        if flow_peak < 10
            opts = ({peak: 3+3*i, max: 6+3*i, ticks:[0, 2+1*i, 4+2*i, 6+3*i]} for i in [0..4])
        else
            opts = ({peak: 30+30*i, max: 60+30*i, ticks:[0, 20+10*i, 40+20*i, 60+30*i]} for i in [0..40])
        for {peak, max, ticks} in opts
            if flow_peak < peak
                break
        return [max, ticks]

    flow_data: () =>
        type = @flow_type()
        # type = @vm.flow_type
        #other_type = @combine_type()
        offset = 120 - @sd.stats.items.length
        #data = ([i+offset, (sample[type] + sample[other_type])] for sample, i in @sd.stats.items)
        data = ([i+offset, sample[type]] for sample, i in @sd.stats.items)
        zero = [0...offset].map (e) -> [e, 0]
        zero.concat data

    flow_type: =>
        feature = @sd.systeminfo.data.feature
        rw = if @vm.flow_type is "fwrite_mb" then "write" else "read"
        if "monfs" in feature
            return "f#{rw}_mb"
        else if "xfs" in feature
            return "n#{rw}_mb"
        else
            return "#{rw}_mb"

    add_time_to_journal:(items) =>
            journals = []
            change_time = `function funConvertUTCToNormalDateTime(utc)
            {
                var date = new Date(utc);
                var ndt;
                ndt = date.getFullYear()+"/"+(date.getMonth()+1)+"/"+date.getDate()+"-"+date.getHours()+":"+date.getMinutes()+":"+date.getSeconds();
                return ndt;
            }`
            for item in items
                localtime = change_time(item.created_at*1000)
                item.message =  "[#{localtime}]  #{item.message}"
                journals.push item
            return journals
            
    combine_type: ->
        if @vm.flow_type[0] is "f"
            type = @vm.flow_type.slice 1
        else
            type = "f" + @vm.flow_type
        type

    plot_flow: (max, ticks) =>
        @$flow_stats = $.plot $("#flow_stats"), [@flow_data()],
            series:
                shadowSize: 1
            lines:
                show: true
                lineWidth: 0.2
                fill: true
                fillColor:
                    colors: [
                        {opacity: 0.1}
                        {opacity: 1}
                    ]
            yaxis:
                min: 0
                max: max
                tickFormatter: (v) -> "#{v}MB"
                ticks: ticks
            xaxis:
                show: false
            colors: ["#6ef146"]
            grid:
                tickColor: "#a8a3a3"
                borderWidth: 0

    refresh_flow: () =>
        [max, ticks] = @flow_data_opt()
        if max is @flow_max
            @$flow_stats.setData [@flow_data()]
            @$flow_stats.draw()
        else
            @flow_max = max
            @plot_flow(max, ticks)

class DiskPage extends Page
    constructor: (@sd) ->
        super "diskpage-", "html/diskpage.html"
        $(@sd.disks).on "updated", (e, source) =>
            @vm.disks = @subitems()
            @vm.need_format = @need_format()
            @vm.slots = @get_slots()
            @vm.raids = @get_raids()
        console.log "diskssssssssssss"
        console.log @vm.raids
        console.log @vm.disks                    

    define_vm: (vm) =>
        vm.disks = @subitems()
        vm.slots = @get_slots()
        vm.raids = @get_raids()
        vm.lang = lang.diskpage
        vm.fattr_health = fattr.health
        vm.fattr_role = fattr.role
        vm.fattr_host = fattr.host
        vm.fattr_cap = fattr.cap
        vm.fattr_import = fattr._import
        vm.fattr_disk_status = fattr.disk_status
        vm.fattr_raid_status = fattr.raid_status
        vm.format_disk = @format_disk
        vm.format_all = @format_all
        vm.need_format = @need_format()
        
        vm.disk_list = @disk_list
        
    rendered: () =>
        super()
        $("[data-toggle='tooltip']").tooltip()
        $ ->
        $("#myTab li:eq(0) a").tab "show"

    subitems: () =>
        subitems @sd.disks.items,location:"",host:"",health:"",raid:"",role:"",cap_sector:""

    get_slots: () =>
        console.log @sd.dsus.items
        console.log @sd.disks.items
        console.log @subitems()
        slotgroups = []
        slotgroup = []

        dsu_disk_num = 0
        raid_color_map = @_get_raid_color_map()
        for dsu in @sd.dsus.items
            for i in [1..dsu.support_disk_nr]
                o = @_has_disk(i, dsu, dsu_disk_num)
                o.raidcolor = raid_color_map[o.raid]
                o.info = @_get_disk_info(i, dsu)
                slotgroup.push o
                if i%4 is 0
                    slotgroups.push slotgroup
                    slotgroup = []
            dsu_disk_num = dsu_disk_num + dsu.support_disk_nr

        console.log slotgroups
        return slotgroups

    get_raids: () =>
        raids = []
        raid_color_map = @_get_raid_color_map()
        for key, value of raid_color_map
            o = name:key, color:value
            raids.push o
        return raids

    disk_list: (disks) =>
        if disks.info == "none"
            return "空盘"
        else
            return @_translate(disks.info)

    _translate: (obj) =>
        status = ''
        health = {'normal':'正常', 'down':'下线', 'failed':'损坏'}
        role = {'data':'数据盘', 'spare':'热备盘', 'unused':'未使用', \
        'kicked':'损坏', 'global_spare':'全局热备盘', 'data&spare':'数据热备盘'}
        type = {'enterprise': '企业盘', 'monitor': '监控盘', 'sas': 'SAS盘'}
        
        $.each obj, (key, val) ->
            switch key
                when 'cap_sector'
                    status += '容量: ' + fattr.cap(val)+ '<br/>'
                when 'health'
                    status += '健康: ' + health[val] + '<br/>'
                when 'role'
                    status += '状态: ' + role[val] + '<br/>'
                when 'raid'
                    if val.length == 0
                        val = '无'
                    status += '阵列: ' + val + '<br/>'
                when 'vendor'
                    status += '品牌: ' + val + '<br/>'
                when 'sn'
                    status += '序列号: ' + val + '<br/>'
                when 'model'
                    status += '型号: ' + val + '<br/>'
                when 'type'
                    name = '未知'
                    mod = obj.model.match(/(\S*)-/)[1];
                    $.each disks_type, (j, k) ->
                        if mod in k
                            name = type[j]
                    status += '类型: ' + name + '<br/>'
                    
        status
        
    _get_disk_info: (slotNo, dsu) =>
        for disk in @sd.disks.items
            if disk.location is "#{dsu.location}.#{slotNo}"
                info = health:disk.health, cap_sector:disk.cap_sector, \
                role:disk.role, raid:disk.raid, vendor:disk.vendor, \
                sn:disk.sn, model:disk.model, type:disk.type
                return info
        'none'
        
    _has_disk: (slotNo, dsu, dsu_disk_num) =>
        loc = "#{dsu_disk_num + slotNo}"
        for disk in @subitems()
            if disk.location is "#{dsu.location}.#{slotNo}"
                rdname = if disk.raid is ""\
                    then "noraid"\
                    else disk.raid
                rdrole = if disk.health is "down"\
                    then "down"\
                    else disk.role
                o = slot: loc, role:rdrole, raid:rdname, raidcolor: ""
                return o
        o = slot: loc, role:"nodisk", raid:"noraid", raidcolor: ""
        return o

    _get_raid_color_map: () =>
        map = {}
        raids = []
        i = 1
        has_global_spare = false
        for disk in @subitems()
            if disk.role is "global_spare"
                has_global_spare = true
                continue
            rdname = if disk.raid is ""\
                then "noraid"\
                else disk.raid
            if rdname not in raids
                raids.push rdname
        for raid in raids
            map[raid] = "color#{i}"
            i = i + 1
        map["noraid"] = "color0"
        if has_global_spare is true
            map["global_spare"] = "color5"
        return map

    format_disk: (element) =>
        if element.host is "native"
            return
        (new ConfirmModal lang.diskpage.format_warning(element.location), =>
            @frozen()
            chain = new Chain
            chain.chain =>
                (new DiskRest @sd.host).format element.location
            chain.chain @sd.update("disks")
            show_chain_progress(chain).done =>
                @attach()
        ).attach()

    format_all: =>
        disks = @_need_format_disks()
        (new ConfirmModal lang.diskpage.format_all_warning, =>
            @frozen()
            chain = new Chain
            rest = new DiskRest @sd.host
            i = 0
            for disk in disks
                chain.chain ->
                    (rest.format disks[i].location).done -> i += 1
            chain.chain @sd.update("disks")
            show_chain_progress(chain).done =>
                @attach()
        ).attach()

    need_format: =>
        return if (@_need_format_disks()).length isnt 0 then true else false

    _need_format_disks: =>
        disks = @subitems()
        needs = (disk for disk in disks when disk.host isnt "native")

class RaidPage extends DetailTablePage
    constructor: (@sd) ->
        super "raidpage-", "html/raidpage.html"

        table_update_listener @sd.raids, "#raid-table", =>
            @vm.raids = @subitems() if not @has_frozen

        $(@sd).on "raid", (e, raid) =>
            for r in @sd.raids.items
                if r.id is raid.id
                    r.health = raid.health
                    r.rqr_count = raid.rqr_count
                    r.rebuilding = raid.rebuilding
                    r.rebuild_progress = raid.rebuild_progress
            for r in @vm.raids
                if r.id is raid.id
                    r.rqr_count = raid.rqr_count
                    if r.rebuilding and raid.health == 'normal'
                        count = 5
                        delta = (1-r.rebuild_progress) / count
                        i = 0
                        tid = setInterval (=>
                            if i < 5
                                r.rebuild_progress += delta
                                i+=1
                            else
                                clearInterval tid
                                r.health = raid.health
                                r.rebuilding = raid.rebuilding
                                r.rebuild_progress = raid.rebuild_progress), 800
                    else
                        r.health = raid.health
                        r.rebuilding = raid.rebuilding
                        r.rebuild_progress = raid.rebuild_progress

    define_vm: (vm) =>
        vm.raids = @subitems()
        vm.lang = lang.raidpage
        vm.fattr_health = fattr.health
        vm.fattr_rebuilding = fattr.rebuilding
        vm.fattr_cap_usage = fattr.cap_usage_raid
        vm.all_checked = false

        vm.detail = @detail
        vm.create_raid = @create_raid
        vm.delete_raid = @delete_raid
        vm.set_disk_role = @set_disk_role

        vm.$watch "all_checked", =>
            for r in vm.raids
                r.checked = vm.all_checked

    subitems: () =>
        subitems(@sd.raids.items, id:"", name:"", level:"", chunk_kb:"",\
            health:"", rqr_count:"", rebuilding:"", rebuild_progress:0,\
            cap_sector:"", used_cap_sector:"", detail_closed:true, checked:false)

    rendered: () =>
        @vm.raids = @subitems() if not @has_frozen
        super()

        @data_table = $("#raid-table").dataTable(
            sDom: 't'
            oLanguage:
                sEmptyTable: "没有数据")

    detail_html: (raid) =>
        html = avalon_templ raid.id, "html/raid_detail_row.html"
        o = @sd.raids.get raid.id
        vm = avalon.define raid.id, (vm) =>
            vm.disks = subitems @sd.raid_disks(o),location:"",health:"",role:""
            vm.lang  = lang.raidpage.detail_row
            vm.fattr_health = fattr.health
            vm.fattr_role   = fattr.role

        $(@sd.disks).on "updated.#{raid.id}", (e, source) =>
            vm.disks = subitems @sd.raid_disks(o),location:"",health:"",role:""
        return [html, vm]

    close_detial: (raid) =>
        $(@sd.disks).off ".#{raid.id}"

    set_disk_role: () =>
        if @sd.raids.items.length > 0
            (new RaidSetDiskRoleModal(@sd, this)).attach()
        else
            (new MessageModal(lang.raid_warning.no_raid)).attach()

    create_raid: () =>
        (new RaidCreateModal(@sd, this)).attach()

    delete_raid: () =>
        deleted = ($.extend({},r.$model) for r in @vm.raids when r.checked)
        if deleted.length isnt 0
            (new RaidDeleteModal(@sd, this, deleted)).attach()
        else
            (new MessageModal(lang.raid_warning.no_deleted_raid)).attach()

class VolumePage extends DetailTablePage
    constructor: (@sd) ->
        super "volumepage-", "html/volumepage.html"
        table_update_listener @sd.volumes, '#volume-table', =>
            @vm.volumes = @subitems() if not @has_frozen
        table_update_listener @sd.filesystem, '#volume-table', =>
            @vm.volumes = @subitems() if not @has_frozen
        $(@sd.systeminfo).on "updated", (e, source) =>
            feature = @sd.systeminfo.data.feature
            @vm.show_fs = if "monfs" in feature or "xfs" in feature then true else false
            @fs_type = if "monfs" in feature then "monfs" else if "xfs" in feature then "xfs"
            @vm.show_cap = if "xfs" in feature then true else false
            @vm.show_cap_new = if "monfs" in feature or "ipsan" in feature then true else false
            @vm.show_precreate = if "monfs" in feature or "xfs" in feature and @_settings.znv then true else false
       
        @show_chosendir = @_settings.chosendir      #cangyu varsion can choose the target directory to mount
         
        failed_volumes = []
        @lock = false
        $(@sd).on "volume", (e, volume) =>
            @lock = volume.syncing
            if @_settings.sync
                if volume.event == "volume.created"
                    @lock = true
                else if volume.event == "volume.sync_done"
                    @lock = false                    
            for r in @sd.volumes.items
                if r.id is volume.id
                    r.sync_progress = volume.sync_progress
                    r.sync = volume.syncing
                    r.event = volume.event
            for r in @vm.volumes
                if r.id is volume.id
                    r.sync_progress = volume.sync_progress
                    r.syncing = volume.syncing
                    r.event = volume.event                               
                    r.sync = volume.syncing
                    
            real_failed_volumes = []
            if volume.event == "volume.failed"
                volume = @sd.volumes.get e.uuid
                failed_volumes.push r
            for i in @sd.volumes.items
                if i.health == "failed"
                    real_failed_volumes.push i
            if failed_volumes.length == real_failed_volumes.length and failed_volumes.length
                (new SyncDeleteModal(@sd, this, real_failed_volumes)).attach()
                failed_volumes = []
                return

    define_vm: (vm) =>
        @_settings = new (require("settings").Settings)
        vm.volumes = @subitems()
        vm.lang = lang.volumepage
        vm.fattr_health = fattr.health
        vm.fattr_cap = fattr.cap
        vm.fattr_precreating = fattr.precreating        
        vm.detail = @detail
        vm.all_checked = false
        vm.create_volume = @create_volume
        vm.delete_volume = @delete_volume
        vm.enable_fs  = @enable_fs
        vm.disable_fs = @disable_fs
        vm.fattr_synchronizing = fattr.synchronizing
        vm.fattr_cap_usage_vol = fattr.cap_usage_vol
        
        vm.show_sync = @_settings.sync
        vm.enable_sync = @enable_sync
        vm.pause_synv = @pause_sync
        vm.disable_sync = @disable_sync      
        vm.sync_switch = @sync_switch
        
        vm.show_fs = @show_fs
        
        
        vm.show_precreate = @show_precreate
        vm.pre_create = @pre_create
        vm.server_start = @server_start
        vm.server_stop = @server_stop
        
        vm.show_cap = @show_cap
        vm.$watch "all_checked", =>
            for v in vm.volumes
                v.checked = vm.all_checked



    subitems: () =>
        items = subitems @sd.volumes.items, id:"", name:"", health:"", cap_sector:"",\
             used:"", detail_closed:true, checked:false, fs_action:"enable",\
             syncing:'', sync_progress: 0, sync:'', precreating:"",\
             precreate_progress: "", precreate_action:"unavail", event: ""     
        for v in items
            if v.used
                v.fs_action = "disable"
                v.precreate_action = "precreating"
                if v.precreating isnt true and v.precreate_progress == 0
                    v.precreate_action = "enable_precreate"                   
            else
                v.fs_action = "enable"
                v.precreate_action = "unavail"                        
        return items  
        
    rendered: () =>
        super()
        @vm.volumes = @subitems() if not @has_frozen
        @data_table = $("#volume-table").dataTable dtable_opt(retrieve: true)
        $(".dataTables_filter input").addClass "m-wrap small"
        $(".dataTables_length select").addClass "m-wrap small"
    
    detail_html: (volume) =>
        html = avalon_templ volume.id, "html/volume_detail_row.html"
        o = @sd.volumes.get volume.id
        vm = avalon.define volume.id, (vm) =>
            vm.initrs = subitems @sd.volume_initrs(o),active_session:"",wwn:""
            vm.lang = lang.volumepage.detail_row
            vm.fattr_active_session = fattr.active_session

        $(@sd.initrs).on "updated.#{volume.id}", (e, source) =>
            vm.initrs = subitems @sd.volume_initrs(o),active_session:"",wwn:""
        return [html, vm]

    close_detial: (volume) =>
        $(@sd.initrs).off ".#{volume.id}"

    create_volume: () =>
        if @lock
            volume_syncing = []
            for i in @subitems()
                if i.syncing == true
                    volume_syncing.push i.name        
            (new MessageModal lang.volumepage.th_syncing_warning(volume_syncing)).attach()
            return
            
        raids_available = []
        for i in @sd.raids.items
            if i.health == "normal"
                raids_available.push i
        
        if raids_available.length > 0
            
            (new VolumeCreateModal(@sd, this)).attach()
        else
            (new MessageModal(lang.volume_warning.no_raid)).attach()

    delete_volume: () =>
        
        ###
        deleted = ($.extend({},v.$model) for v in @vm.volumes when v.checked)
        lvs_with_fs = []
        for fs_o in @sd.filesystem.data
            lvs_with_fs.push fs_o.volume

        for v in deleted
            if v.used
                if v.name in lvs_with_fs
                    (new MessageModal(lang.volume_warning.fs_on_volume(v.name))).attach()
                else if @sd.volume_initrs(v).length isnt 0
                    (new MessageModal(lang.volume_warning.volume_mapped_to_initrs(v.name))).attach()
                return
            else if @lock
                volume_syncing = []
                for i in @subitems()
                    if i.syncing == true
                        volume_syncing.push i.name             
                (new MessageModal lang.volumepage.th_syncing_warning(volume_syncing)).attach()
                return
        if deleted.length isnt 0
            (new VolumeDeleteModal(@sd, this, deleted)).attach()
        else
            (new MessageModal(lang.volume_warning.no_deleted_volume)).attach()
###
    _apply_fs_name: () =>
        max = @_settings.fs_max
        used_names=[]
        availiable_names=[]
        for fs_o in @sd.filesystem.data
            used_names.push fs_o.name
        for i in [1..max]
            if "myfs#{i}" in used_names
                continue
            else
                availiable_names.push "myfs#{i}"

        if availiable_names.length is 0
            return ""
        else
            return availiable_names[0]

    enable_fs: (v) =>
        if @sync
            (new MessageModal lang.volumepage.th_syncing_warning).attach()
            return
        fs_name = @_apply_fs_name()
        feature = @sd.systeminfo.data.feature[0]
        
        if v.used
            (new MessageModal(lang.volume_warning.volume_mapped_to_fs(v.name))).attach()
        else if fs_name is "" 
            if 'monfs' == feature 
                (new MessageModal(lang.volume_warning.only_support_one_fs)).attach()
            else if 'xfs' == feature
                (new MessageModal(lang.volume_warning.over_max_fs)).attach()
        else if @show_chosendir
            (new FsCreateModal(@sd, this, v.name)).attach()
        else if @_settings.znv
            (new FsChooseModal(@sd, this, fs_name, v.name)).attach()            
        else
            (new ConfirmModal(lang.volume_warning.enable_fs, =>
                @frozen()
                chain = new Chain()
                chain.chain(=> (new FileSystemRest(@sd.host)).create fs_name, @fs_type, v.name)
                    .chain @sd.update("filesystem")
                show_chain_progress(chain).done =>
                    @attach()
                .fail (data)=>
                    (new MessageModal(lang.volume_warning.over_max_fs)).attach()
                    @attach())).attach()
                    
    disable_fs: (v) =>
        if @sync
            (new MessageModal lang.volumepage.th_syncing_warning).attach()
            return

        fs_name = ""
        for fs_o in @sd.filesystem.data
            if fs_o.volume is v.name
                fs_name = fs_o.name
                break

        (new ConfirmModal(lang.volume_warning.disable_fs, =>
            @frozen()
            chain = new Chain()
            chain.chain(=> (new FileSystemRest(@sd.host)).delete fs_name)
                .chain @sd.update("filesystem")
            show_chain_progress(chain).done =>
                @attach())).attach()

    sync_switch: (v) =>
        console.log v
        if v.syncing
            @disable_sync(v)
        else
            @enable_sync(v)           

            
    enable_sync: (v) =>
        if v.health != 'normal'
            (new MessageModal lang.volume_warning.disable_sync).attach()
            return    
        (new ConfirmModal(lang.volume_warning.enable_sync(v.name), =>
            @frozen()
            chain = new Chain()
            chain.chain => 
                (new SyncConfigRest(@sd.host)).sync_enable(v.name)
            show_chain_progress(chain,true).done =>
                @attach()
            .fail (data) =>
                (new MessageModal lang.volume_warning.syncing_error).attach()
            )).attach()               
                #(new MessageModal lang.volumepage.syncing).attach())

    disable_sync: (v) =>
        chain = new Chain()
        chain.chain => 
            (new SyncConfigRest(@sd.host)).sync_disable(v.name)
        (show_chain_progress chain).done =>
            @attach()
        .fail (data) =>
            (new MessageModal lang.volume_warning.syncing_error).attach()

    pre_create: (v) =>
        chain = new Chain
        chain.chain(=> (new ZnvConfigRest(@sd.host)).precreate v.name)
         #   .chain @sd.update("volumes")
        (show_chain_progress chain).done 

    server_start: (bool) =>
        chain = new Chain
        chain.chain =>
            (new ZnvConfigRest(@sd.host)).start_service(bool)
        (show_chain_progress chain).done =>
            (new MessageModal lang.volumepage.btn_enable_server).attach()

    server_stop: (bool) =>
        chain = new Chain
        chain.chain =>
            (new ZnvConfigRest(@sd.host)).stop_service(bool)
        (show_chain_progress chain).done (data)=>
            (new MessageModal lang.volumepage.btn_disable_server).attach()
            
class InitrPage extends DetailTablePage
    constructor: (@sd) ->
        super "initrpage-", "html/initrpage.html"

        table_update_listener @sd.initrs, "#initr-table", =>
            @vm.initrs = @subitems() if not @has_frozen

        $(@sd).on "initr", (e, initr) =>
            for i in @vm.initrs
                if i.id is initr.id
                    i.active_session = initr.active_session

        @vm.show_iscsi = if @_iscsi.iScSiAvalable() and !@_settings.fc then true else false

    define_vm: (vm) =>
        @_settings = new (require("settings").Settings)
        @_iscsi = new IScSiManager
        vm.initrs = @subitems()
        vm.lang = lang.initrpage
        vm.fattr_active_session = fattr.active_session
        vm.fattr_show_link = fattr.show_link
        vm.detail = @detail
        vm.all_checked = false

        vm.create_initr = @create_initr
        vm.delete_initr = @delete_initr

        vm.map_volumes = @map_volumes
        vm.unmap_volumes = @unmap_volumes

        vm.show_iscsi = @show_iscsi
        vm.link_initr = @link_initr
        vm.unlink_initr = @unlink_initr
        
        vm.$watch "all_checked", =>
            for v in vm.initrs
                v.checked = vm.all_checked
    
    subitems: () =>
        arrays = subitems @sd.initrs.items, id:"", wwn:"", active_session:"",\
            portals:"", detail_closed:true, checked:false 
        for item in arrays
            item.name = item.wwn
            item.iface = (portal for portal in item.portals).join ", "
        return arrays

    rendered: () =>
        @vm.initrs = @subitems()
        @data_table = $("#initr-table").dataTable dtable_opt(retrieve: true)
        $(".dataTables_filter input").addClass "m-wrap small"
        $(".dataTables_length select").addClass "m-wrap small"
        super()

    detail_html: (initr) =>
        html = avalon_templ initr.id, "html/initr_detail_row.html"
        o = @sd.initrs.get initr.id
        vm = avalon.define initr.id, (vm) =>
            vm.volumes = subitems @sd.initr_volumes(o),name:""
            vm.lang = lang.initrpage.detail_row
        return [html, vm]

    create_initr: () =>   
        (new InitrCreateModal @sd, this).attach()

    delete_initr: () =>
        selected = ($.extend({},i.$model) for i in @vm.initrs when i.checked)
        initrs = (@sd.initrs.get initr.id for initr in selected)
        if initrs.length == 0
            (new MessageModal lang.initr_warning.no_deleted_intir).attach()
        else
            for initr in initrs
                volumes = @sd.initr_volumes initr
                if volumes.length isnt 0
                    (new MessageModal lang.initr_warning.intitr_has_map(initr.wwn)).attach()
                    return
            (new InitrDeleteModal @sd, this, selected).attach()

    map_volumes: (index) =>
        selected = @sd.initrs.get @vm.initrs[index].id
        volumes = []
        for i in @sd.volumes.items
            if i.health == "normal"
                volumes.push i
        if volumes.length == 0
            (new MessageModal lang.initr_warning.no_spared_volume).attach()
        else if selected.active_session
            (new MessageModal lang.initr_warning.detect_iscsi(selected.wwn)).attach()
        else
            (new VolumeMapModal @sd, this, selected).attach()

    unmap_volumes: (index) =>
        selected = @sd.initrs.get @vm.initrs[index].id
        volumes = @sd.initr_volumes selected
        if volumes.length == 0
            (new MessageModal lang.initr_warning.no_attached_volume).attach()
        else if selected.active_session
            (new MessageModal lang.initr_warning.unmap_iscsi(selected.wwn)).attach()
        else
            (new VolumeUnmapModal @sd, this, selected).attach()

    link_initr: (index) =>
        for indexs in [0..@vm.initrs.length-1] when @sd.initrs.items[indexs].active_session is true
            (new MessageModal lang.initr_warning.intitr_has_link).attach()
            return
        selected = @sd.initrs.get @vm.initrs[index].id
        portals = []
        for portal in @sd.networks.items when portal.id in selected.portals
            portals.push portal.ipaddr
            @_iscsi.linkinit selected.wwn,portal.ipaddr
        (new ConfirmModal_link(
                lang.initr_link_warning.confirm_link(selected.wwn), =>
                    chain = new Chain()
                    @_iscsi_link index
            )).attach()

    unlink_initr: (index) =>
        selected = @sd.initrs.get @vm.initrs[index].id
        portals = []
        for portal in @sd.networks.items when portal.id in selected.portals
            portals.push portal.ipaddr
            @_iscsi.linkinit selected.wwn,portal.ipaddr
        (new ConfirmModal_unlink(
                lang.initr_link_warning.undo_link(selected.wwn), =>
                    chain = new Chain()
                    @_iscsi_unlink index
            )).attach()

    _iscsi_link: (index) =>
        selected = @sd.initrs.get @vm.initrs[index].id
        portals = []
        for portal in @sd.networks.items when portal.id in selected.portals
            portals.push portal.ipaddr 
        @frozen()
        chain = new Chain()
        chain.chain @sd.update('initrs')
        show_chain_progress(chain).done =>
            if @_iscsi.connect selected.wwn, portals
                @attach()
            else
                (new MessageModal(lang.initr_link_warning.link_err)).attach()
                @attach()
        .fail =>
            @attach()
        chains = new Chain()
        chains.chain @sd.update('initrs')

    _iscsi_unlink: (index) =>
        selected = @sd.initrs.get @vm.initrs[index].id
        portals = []
        for portal in @sd.networks.items when portal.id in selected.portals
            portals.push portal.ipaddr 
        @frozen()
        chain = new Chain()
        chain.chain @sd.update('initrs')
        show_chain_progress(chain).done =>
            if @_iscsi.disconnect selected.wwn, portals
                @attach()
            else
                (new MessageModal(lang.initr_link_warning.link_err)).attach()
                @attach()
        .fail =>
            @attach()
        chains = new Chain()
        chains.chain @sd.update('initrs')
        
            
class SettingPage extends Page
    constructor: (@dview, @sd) ->
        super "settingpage-", "html/settingpage.html"
        @edited = null
        @settings = new SettingsManager
        $(@sd.networks).on "updated", (e, source) =>
            @vm.ifaces = @subitems()
            @vm.able_bonding = @_able_bonding()
            @vm.local_serverip = @sd.networks.items[1].ipaddr
            
        $(@sd.gateway).on "updated", (e, source) =>
            @vm.gateway = @sd.gateway.data.gateway

        @vm.server_options = [
          { value: "store_server", msg: "存储服务器" }
          { value: "forward_server", msg: "转发服务器" }
        ]
        
    #znv_server
               
    define_vm: (vm) =>
        @_settings = new (require("settings").Settings) 
        vm.lang = lang.settingpage
        vm.ifaces = @subitems()
        vm.gateway = @sd.gateway.data.gateway
        vm.old_passwd = ""
        vm.new_passwd = ""
        vm.confirm_passwd = ""
        vm.submit_passwd = @submit_passwd
        vm.keypress_passwd = @keypress_passwd
        vm.edit_iface = (e) =>
            for i in @vm.ifaces
                i.edit = false
            e.edit = true
            @edited = e
        vm.cancel_edit_iface = (e) =>
            e.edit = false
            @edited = null
            i = @sd.networks.get e.id
            e.ipaddr  = i.ipaddr
            e.netmask = i.netmask
        vm.submit_iface   = @submit_iface
        vm.submit_gateway = @submit_gateway
        vm.able_bonding = true
        vm.eth_bonding = @eth_bonding
        vm.eth_bonding_cancel = @eth_bonding_cancel
        
        vm.znv_server = @znv_server
        vm.server_options = ""
        vm.enable_server = true
        vm.server_switch = @_settings.znv
        vm.select_ct = true
        vm.serverid = ""
        vm.local_serverip = ""
        vm.local_serverport = "8003"
        vm.cmssverip = ""
        vm.cmssverport = "8000"
        vm.directory ="/nvr/d1;/nvr/d2"
                
    subitems: () =>
        items = subitems @sd.networks.items,id:"",ipaddr:"",iface:"",netmask:"",type:"",edit:false
        removable = []
        if not @_able_bonding()
            for eth in items
                removable.push eth if eth.type isnt "bond-slave"
            return removable
        items

    rendered: () =>
        super()
        $('.tooltips').tooltip()
        $.validator.addMethod("same", (val, element) =>
            if @vm.new_passwd != @vm.confirm_passwd
                return false
            else
                return true
        , "两次输入的新密码不一致")

        $("#server_select").chosen()
        chosen = $("#server_select")
        chosen.change =>
            if chosen.val() == "store_server"
                @vm.local_serverport = 8003
                @vm.select_ct = true
            else
                @vm.local_serverport = 8002
                @vm.select_ct = false
                
        $("form.passwd").validate(
            valid_opt(
                rules:
                    old_passwd:
                        required: true
                        maxlength: 32
                    new_passwd:
                        required: true
                        maxlength: 32
                    confirm_passwd:
                        required: true
                        maxlength: 32
                        same: true
                messages:
                    old_passwd:
                        required: "请输入您的旧密码"
                        maxlength: "密码长度不能超过32个字符"
                    new_passwd:
                        required: "请输入您的新密码"
                        maxlength: "密码长度不能超过32个字符"
                    confirm_passwd:
                        required: "请再次输入您的新密码"
                        maxlength: "密码长度不能超过32个字符"))

        Netmask = require("netmask").Netmask
        $.validator.addMethod("validIP", (val, element) =>
            regex = /^\d{1,3}(\.\d{1,3}){3}$/
            if not regex.test val
                return false
            try
                n = new Netmask(val)
                return true
            catch error
                return false
        )

        $.validator.addMethod("validport", (val, element) =>
            regex = /^[0-9]*$/
            if not regex.test val
                return false
            try
                n = new Netmask(val)
                return true 
            catch error
                return true                
        )
                
        $.validator.addMethod("samesubnet", (val, element) =>
            try
                subnet = new Netmask("#{@edited.ipaddr}/#{@edited.netmask}")
                for n in @sd.networks.items
                    if n.iface == @edited.iface
                        continue
                    if n.ipaddr isnt "" and subnet.contains n.ipaddr
                        return false
                return true
            catch error
                return false
        ,(params, element) =>
            try
                subnet = new Netmask("#{@edited.ipaddr}/#{@edited.netmask}")
                for n in @sd.networks.items
                    if n.iface == @edited.iface
                        continue
                    if n.ipaddr isnt "" and subnet.contains n.ipaddr
                        return "和#{n.iface}处在同一网段，请重新配置网卡"
            catch error
                return "网卡配置错误，请重新配置网卡"
        )
        
        $.validator.addMethod("using", (val, element) =>
            for initr in @sd.initrs.items
                if @edited.iface in initr.portals
                    return false
            return true
        ,(val, element) =>
            for initr in @sd.initrs.items
                if @edited.iface in initr.portals
                    return "客户端#{initr.wwn}正在使用#{@edited.iface}，请删除客户端，再配置网卡"
        )

        $("#network-table").validate(
            valid_opt(
                rules:
                    ipaddr:
                        required: true
                        validIP: true
                        samesubnet: true
                        using: true
                    netmask:
                        required: true
                        validIP: true
                messages:
                    ipaddr:
                        required: "请输入IP地址"
                        validIP: "无效IP地址"
                    netmask:
                        required: "请输入子网掩码"
                        validIP: "无效子网掩码"))

        $.validator.addMethod("reachable", (val, element) =>
            for n in @sd.networks.items
                try
                    subnet = new Netmask("#{n.ipaddr}/#{n.netmask}")
                catch error
                    # some ifaces have empty ipaddr, so ignore it
                    continue

                if subnet.contains val
                    return true
            return false
        )

        $("form.gateway").validate(
            valid_opt(
                rules:
                    gateway:
                        required: true
                        validIP: true
                        reachable: true
                messages:
                    gateway:
                        required: "请输入网关地址"
                        validIP: "无效网关地址"
                        reachable: "路由不在网卡网段内"))

        $("#server-table").validate(
            valid_opt(
                rules:
                    cmssverip:
                        required: true
                        validIP: true
                        reachable: true
                    cmssverport:
                        required: true
                        validport: true
                        #reachable: true
                messages:
                    cmssverip:
                        required: "请输入中心IP"
                        validIP: "无效IP地址"
                        reachable: "路由不在网卡网段内"
                    cmssverport:
                        required: "请输入监听端口"
                        validport: "无效端口"
                        #reachable: "端口不存在"
                        ))

        $("form.server").validate(
            valid_opt(
                rules:
                    serverid:
                        required: true
                        validport: true
                        #reachable: true
                    local_serverip:
                        required: true
                        validIP: true
                        reachable: true
                    local_serverport:
                        required: true
                        validport: true
                        #reachable: true
           
                messages:
                    serverid:
                        required: "请输入服务器ID"
                        validport: "无效服务器ID"
                        #reachable: "路由不在网卡网段内"                    
                    local_serverip:
                        required: "请输入本机IP"
                        validIP: "无效IP地址"
                        reachable: "路由不在网卡网段内"
                    local_serverport:
                        required: "请输入监听端口"
                        validport: "无效端口"
                        #reachable: "端口不存在"
                        ))

    submit_passwd: () =>
        if $("form.passwd").validate().form()
            if @vm.old_passwd is @vm.new_passwd
                (new MessageModal lang.settingpage.useradmin_error).attach()
            else
                chain = new Chain
                chain.chain =>
                    (new UserRest(@sd.host)).change_password("admin", @vm.old_passwd, @vm.new_passwd)

                (show_chain_progress chain).done =>
                    @vm.old_passwd = ""
                    @vm.new_passwd = ""
                    @vm.confirm_passwd = ""
                    (new MessageModal lang.settingpage.message_newpasswd_success).attach()


    keypress_passwd: (e) =>
        @submit_passwd() if e.which is 13

    submit_iface: (e) =>
        for portal in @sd.networks.items when portal.ipaddr is e.ipaddr
            (new MessageModal lang.settingpage.iface_error).attach()
            return
        if $("#network-table").validate().form()
            (new ConfirmModal(lang.network_warning.config_iface, =>
                e.edit = false
                @dview.reconnect = true
                chain = new Chain
                chain.chain =>
                    rest = new NetworkRest @sd.host
                    if e.type is "normal"
                        return rest.config e.iface,e.ipaddr,e.netmask
                    else if e.type is "bond-master"
                        return rest.modify_eth_bonding e.ipaddr, e.netmask
                show_chain_progress(chain, true).fail =>
                    index = window.adminview.find_nav_index @dview.menuid
                    window.adminview.remove_tab index if index isnt -1
            )).attach()

    submit_gateway: (e) =>
        if $("form.gateway").validate().form()
            (new ConfirmModal(lang.network_warning.config_gateway, =>
                chain = new Chain()
                chain.chain(=> (new GatewayRest(@sd.host)).config @vm.gateway)
                    .chain @sd.update("networks")
                show_chain_progress(chain).fail =>
                    @vm.gateway = @sd.gateway.ipaddr)).attach()

    znv_server: () =>
        if $("form.server").validate().form() and $("#server-table").validate().form()
            chain = new Chain
            chain.chain =>
                (new ZnvConfigRest(@sd.host)).znvconfig(@vm.select_ct, @vm.serverid, @vm.local_serverip, @vm.local_serverport, @vm.cmssverip, @vm.cmssverport, @vm.directory)
            (show_chain_progress chain).done =>
                (new MessageModal lang.settingpage.service_success).attach()

    _able_bonding: =>
        for eth in @sd.networks.items
            return false if (eth.type.indexOf "bond") isnt -1
        true

    eth_bonding: =>
        if @_has_initr()
            (new MessageModal lang.settingpage.btn_eth_bonding_warning).attach()
            return
        else
            (new EthBondingModal @sd, this).attach()

    eth_bonding_cancel: =>
        if @_has_initr()
            (new MessageModal lang.settingpage.btn_eth_bonding_warning).attach()
            return
        else
            (new ConfirmModal lang.eth_bonding_cancel_warning, =>
                @frozen()
                @dview.reconnect = true
                chain = new Chain
                chain.chain =>
                    (new NetworkRest @sd.host).cancel_eth_bonding()
                show_chain_progress(chain, true).fail =>
                    index = window.adminview.find_nav_index @dview.menuid
                    window.adminview.remove_tab index if index isnt -1
            ).attach()
            return

    _has_initr: =>
        @sd.initrs.items.length isnt 0

class QuickModePage extends Page
    constructor: (@dview, @sd) ->
        super "quickmodepage-", "html/quickmodepage.html"
        @create_files = true
        $(@sd.systeminfo).on "updated", (e, source) =>
            feature = @sd.systeminfo.data.feature
            @vm.show_fs = if "monfs" in feature or "xfs" in feature then true else false

    define_vm: (vm) =>
        vm.lang = lang.quickmodepage
        vm.enable_fs = false
        vm.raid_name = ""
        vm.volume_name = ""
        vm.initr_wwn = ""
        #vm.chunk = "32KB"
        vm.submit = @submit

        @_iscsi = new IScSiManager
        vm.show_iscsi = @_iscsi.iScSiAvalable()
        @enable_iscsi = @_iscsi.iScSiAvalable()

        vm.$watch "volume_name", =>
            vm.initr_wwn = "#{prefix_wwn}:#{vm.volume_name}"

    count_dsu_disks: (dsu) =>
        return (disk for disk in @sd.disks.items\
                         when disk.role is 'unused'\
                         and disk.location.indexOf(dsu.location) is 0).length

    prefer_dsu_location: () =>
        for dsu in @sd.dsus.items
            if @count_dsu_disks(dsu) >= 3
                return dsu.location
        return if @sd.dsus.length then @sd.dsus.items[0].location else '_'

    rendered: () =>
        super()
        #$("[data-toggle='popover']").popover()
        $(".tooltips").tooltip()      
        [rd, lv, wwn] = @_get_unique_names()
        @vm.raid_name   = rd
        @vm.volume_name = lv
        @vm.initr_wwn   = wwn
        $("input:radio").uniform()
        $(".basic-toggle-button").toggleButtons()
        @dsuui = new RaidCreateDSUUI(@sd, "#dsuui")
        @dsuui.attach()
        @add_child @dsuui

        $("#enable-fs").change =>
            @vm.enable_fs = $("#enable-fs").prop "checked"
            if @vm.enable_fs
                @enable_iscsi = false
            else
                @enable_iscsi = $("#enable-iscsi").prop "checked"
        $("#create-files").change =>
            @create_files = $("#create-files").prop "checked"
        $("#enable-iscsi").change =>
            @enable_iscsi = $("#enable-iscsi").prop "checked"

        dsu = @prefer_dsu_location()
        [raids..., spares] = (disk for disk in @sd.disks.items\
                                when disk.role is 'unused'\
                                and disk.location.indexOf(dsu) is 0)
        spares = [] if not spares?
        if raids.length < 3 and spares
            raids = raids.concat spares
            spares = []
        @dsuui.check_disks raids
        @dsuui.check_disks spares, "spare"
        @dsuui.active_tab dsu

        console.log @dsuui.getchunk()

        $.validator.addMethod("min-raid-disks", (val, element) =>
            return @dsuui.get_disks().length >= 3
        )

        $("form", @$dom).validate(
            valid_opt(
                rules:
                    "raid":
                        required: true
                        regex: "^[_a-zA-Z][-_a-zA-Z0-9]*$"
                        duplicated: @sd.raids.items
                        maxlength: 64
                    "volume":
                        required: true
                        regex: "^[_a-zA-Z][-_a-zA-Z0-9]*$"
                        duplicated: @sd.volumes.items
                        maxlength: 64
                    wwn:
                        required: true
                        regex: '^(iqn.2013-01.net.zbx.initiator:)(.*)$'
                        duplicated: @sd.initrs.items
                        maxlength: 96
                    "raid-disks-checkbox":
                        "min-raid-disks": true
                        maxlength: 24
                messages:
                    "raid":
                        required: "请输入阵列名称"
                        duplicated: "阵列名称已存在"
                        maxlength: "阵列名称长度不能超过64个字母"
                    "volume":
                        required: "请输入虚拟磁盘名称"
                        duplicated: "虚拟磁盘名称已存在"
                        maxlength: "虚拟磁盘名称长度不能超过64个字母"
                    wwn:
                        required: "请输入客户端名称"
                        duplicated: "客户端名称已存在"
                        maxlength: "客户端名称长度不能超过96个字母"
                    "raid-disks-checkbox":
                        "min-raid-disks": "级别5阵列最少需要3块磁盘"
                        maxlength: "阵列最多支持24个磁盘"))

    _has_name: (name, res, nattr="name") =>
        for i in res.items
            if name is i[nattr]
                return true
        return false
    
    _all_unique_names: (rd, lv, wwn) =>
        return not (@_has_name(rd, @sd.raids) or @_has_name(lv, @sd.volumes) or @_has_name(wwn, @sd.initrs, "wwn"))

    _get_unique_names: () =>
        rd_name = "rd"
        lv_name = "lv"
        wwn = "#{prefix_wwn}:#{lv_name}"
        if @_all_unique_names rd_name, lv_name, wwn
            return [rd_name, lv_name, wwn]
        else
            i = 1
            while true
                rd = "#{rd_name}-#{i}"
                lv = "#{lv_name}-#{i}"
                wwn = "#{prefix_wwn}:#{lv}"
                if @_all_unique_names rd, lv, wwn
                    return [rd, lv, wwn]
                i += 1

    _get_ifaces: =>
        removable = []
        if not @_able_bonding()
            for eth in @sd.networks.items
                removable.push eth if eth.type isnt "bond-slave"
            return removable
        @sd.networks.items

    _able_bonding: =>
        for eth in @sd.networks.items
            return false if (eth.type.indexOf "bond") isnt -1
        true

    submit: () =>
        if @dsuui.get_disks().length == 0
            (new MessageModal lang.quickmodepage.create_error).attach()
        else if @dsuui.get_disks().length <3
            (new MessageModal lang.quickmodepage.create_error_least).attach()
        else
            if $("form").validate().form()
                @create(@vm.raid_name, @dsuui.getchunk(), @dsuui.get_disks(), @dsuui.get_disks("spare"),\
                    @vm.volume_name, @vm.initr_wwn, @vm.enable_fs, @enable_iscsi, @create_files)

    create: (raid, chunk, raid_disks, spare_disks, volume, initr, enable_fs, enable_iscsi, create_files) =>
        raid_disks = raid_disks.join ","
        spare_disks = spare_disks.join ","

        for n in @_get_ifaces()
            if n.link and n.ipaddr isnt ""
                portals = n.iface
                break
        chain = new Chain
        chain.chain(=> (new RaidRest(@sd.host)).create(name: raid, level: 5,\
            chunk: chunk, raid_disks: raid_disks, spare_disks:spare_disks,\
            rebuild_priority:"", sync:"no", cache:""))
            .chain(=> (new VolumeRest(@sd.host)).create(name: volume,\
                raid: raid, capacity: "all"))
        if enable_fs
            chain.chain(=> (new FileSystemRest(@sd.host)).create "myfs", volume)
            ###
            if create_files
                chain.chain(=> (new CommandRest(@sd.host)).create_lw_files())
            ###
        else
            if not @sd.initrs.get initr
                chain.chain(=> (new InitiatorRest(@sd.host)).create(wwn:initr, portals:portals))
            chain.chain(=> (new InitiatorRest(@sd.host)).map initr, volume)
        chain.chain @sd.update("all")
        show_chain_progress(chain, false, false).done(=>
            if enable_iscsi
                ipaddr = (@sd.host.split ":")[0]
                @_iscsi_link initr, [ipaddr]
            if enable_fs and create_files
                setTimeout (new CommandRest(@sd.host)).create_lw_files, 1000
            @dview.switch_to_page "overview"
            @vm.enable_fs = false).fail(=>
            @vm.enable_fs = false)

    _iscsi_link: (initr, portals) ->
        try
            @_iscsi.connect initr, portals
        catch err
            console.log err

class MaintainPage extends Page
    constructor: (@dview, @sd) ->
        super "maintainpage-", "html/maintainpage.html"
        @settings = new SettingsManager
        $(@sd.systeminfo).on "updated", (e, source) =>
            @vm.server_version = "存储系统版本：#{@sd.systeminfo.data.version}"

    define_vm: (vm) =>
        _settings = new (require("settings").Settings)
        vm.lang = lang.maintainpage
        vm.diagnosis_url = "http://#{@sd.host}/api/diagnosis"
        vm.server_version = "存储系统版本：#{@sd.systeminfo.data.version}"
        vm.gui_version = "客户端版本：#{_settings.version}"
        vm.product_model = "产品型号：CYBX-4U24-T-DC"
        vm.poweroff = @poweroff
        vm.reboot = @reboot
        vm.sysinit = @sysinit
        vm.recover = @recover
        vm.scan_system = @scan_system
        vm.fs_scan = !_settings.sync
        vm.show_productmodel = _settings.product_model

    rendered: () =>
        super()
        $("#fileupload").fileupload(url:"http://#{@sd.host}/api/upgrade")
            .bind("fileuploaddone", (e, data) ->
                (new MessageModal(lang.maintainpage.message_upgrade_success)).attach())
        $("input[name=files]").click ->
            $("tbody.files").html ""

    poweroff: () =>
        (new ConfirmModal(lang.maintainpage.warning_poweroff, =>
            chain = new Chain()
            chain.chain => (new CommandRest(@dview.sd.host)).poweroff()
            show_chain_progress(chain, true).fail =>
                @settings.removeLoginedMachine @dview.host
                @sd.close_socket()
                arr_remove sds, @sd
                setTimeout(@dview.switch_to_login_page, 2000))).attach()

    reboot: () =>
        (new ConfirmModal(lang.maintainpage.warning_reboot, =>
            chain = new Chain()
            chain.chain => (new CommandRest(@dview.sd.host)).reboot()
            show_chain_progress(chain, true).fail =>
                @settings.removeLoginedMachine @dview.host
                @sd.close_socket()
                arr_remove sds, @sd
                setTimeout(@dview.switch_to_login_page, 2000)
                )).attach()

    sysinit: () =>
        (new ConfirmModal_more(@vm.lang.btn_sysinit,@vm.lang.warning_sysinit,@sd,@dview,@settings)).attach()

    recover: () =>
        bool = false
        for i in @sd.raids.items
            if i.health == "failed"
                bool = true
            else
                continue
        
        if bool
            (new ConfirmModal_more(@vm.lang.btn_recover,@vm.lang.warning_recover,@sd,@dview,@settings, this)).attach()
        else
            (new MessageModal(lang.maintainpage.warning_raids_safety)).attach()

    apply_fs_name: () =>
        fs_name = ""
        for fs_o in @sd.filesystem.data
            fs_name = fs_o.name
        return fs_name

    scan_system: (v) =>
        fs_name = @apply_fs_name(v)
        if @sd.filesystem.data.length == 0
            chain = new Chain()
            (show_chain_progress chain).done =>
                (new MessageModal lang.volume_warning.no_fs).attach()
        else
            (new ConfirmModal(lang.volume_warning.scan_fs, =>
                @frozen()
                fsrest = (new FileSystemRest(@sd.host))
               
                (fsrest.scan fs_name).done (data) =>
                    if data.status == "success" and data.detail.length > 0
                        (new ConfirmModal_scan(@sd, this, lang.volumepage.th_scan, lang.volumepage.th_scan_warning, data.detail)).attach()
                    else
                        (new MessageModal lang.volumepage.th_scan_safety).attach()
                    @attach()
                .fail =>
                    (new MessageModal lang.volume_warning.scan_fs_fail).attach()
                )).attach()
                
class LoginPage extends Page
    constructor: (@dview) ->
        super "loginpage-", "html/loginpage.html", class: "login"
        @try_login = false
        @_settings = new SettingsManager
        @settings = new (require("settings").Settings)

    define_vm: (vm) =>
        vm.lang = lang.login
        vm.device = ""
        vm.username = "admin"
        vm.passwd = ""
        #vm.passwd = "admin"
        vm.submit = @submit
        vm.keypress = @keypress
        vm.close_alert = @close_alert

    rendered: () =>
        super()
        
        $.validator.addMethod "isLogined", (value, element) ->
            not (new SettingsManager).isLoginedMachine value
        
        $(".login-form").validate(
            valid_opt(
                rules:
                    device:
                        required: true
                        isLogined: true
                    username:
                        required: true
                    passwd:
                        required: true
                messages:
                    device:
                        required: "请输入存储IP"
                        isLogined: "您已经登录该设备"
                    username:
                        required: "请输入用户名"
                    passwd:
                        required: "请输入密码"
                errorPlacement: (error, elem) ->
                    error.addClass("help-small no-left-padding").
                        insertAfter(elem.closest(".input-icon"))))

        $("#login-ip").typeahead(
            source: @_settings.getUsedMachines()
            items: 6
            updater: (item) =>
                @vm.device = item
        )
        #@video()
        @backstretch = $(".login").backstretch([
            "images/login-bg/1.jpg",
            "images/login-bg/2.jpg",
            "images/login-bg/3.jpg",
            "images/login-bg/4.jpg",
            ], fade: 1000, duration: 5000).data "backstretch"

        return
        
    video: () =>
        $(`function() {
            var BV = new $.BigVideo();
            BV.init();
            BV.show('http://vjs.zencdn.net/v/oceans.mp4');
        }`)
        
    attach: () =>
        super()
        return

    detach: () =>
        super()
        @backstretch?.pause?()

    change_device: (device) =>
        @vm.device = device

    close_alert: (e) =>
        $(".alert-error").hide()

    keypress: (e) =>
        @submit() if e.which is 13

    submit: () =>
        port = @settings.port
        return if @try_login
        if $(".login-form").validate().form()
            @try_login = true
            ifaces_request = new IfacesRest("#{@vm.device}:" + port).query()
            ifaces_request.done (data) =>
                if data.status is "success"
                    isLogined = false
                    login_machine = ""
                    settings = new SettingsManager
                    ifaces = (iface.split("/", 1)[0] for iface in data.detail)
                    for iface in ifaces
                        if settings.isLoginedMachine iface
                            isLogined = true
                            login_machine = iface
                    if isLogined
                        (new MessageModal(
                            lang.login.has_logged_error(login_machine))
                        ).attach()
                        @try_login = false
                    else
                        @_login()
                else
                    @_login()
            ifaces_request.fail =>
                @_login()
            
    _login: () =>
        port = @settings.port
        chain = new Chain
        chain.chain =>
            rest = new SessionRest("#{@vm.device}:" + port)
            query = rest.create @vm.username, @vm.passwd
            query.done (data) =>
                if data.status is "success"
                    @dview.token = data.detail.login_id
        chain.chain @dview.init @vm.device
        show_chain_progress(chain, true).done(=>
            version_request = new SystemInfoRest("#{@vm.device}:" + port).query()
            version_request.done (data) =>
                if data.status is "success"
                    _server_version = data.detail["gui version"].substring 0, 3
                    _app_version = @settings.version.substring 0, 3
                    @_init_device()
                    if _server_version == _app_version
                        @dview.attach()
                    else
                        (new MessageModal lang.login.version_invalid_error).attach()
                        @dview.attach()
            version_request.fail =>
                @_init_device()
                @dview.attach()
        ).fail(=>
            @try_login = false
            $('.alert-error', $('.login-form')).show())
            
        
    
    _init_device: =>
        @try_login = false
        @_settings.addUsedMachine @vm.device
        @_settings.addLoginedMachine @vm.device
        @_settings.addSearchedMachine @vm.device
        return
        
##############################################################################

class CentralLoginPage extends Page
    constructor: (@dview) ->
        super "centralloginpage-", "html/centralloginpage.html", class: "login"
        @try_login = false
        @_settings = new SettingsManager
        @settings = new (require("settings").Settings)
        @vm.show_ip = true

    define_vm: (vm) =>
        vm.lang = lang.centrallogin
        vm.key = "zexabox.com%sam&ace"
        #vm.device = "120.76.128.35"
        vm.device = "192.168.2.82"
        #vm.device = "113.87.161.169"
        #vm.device = "183.39.156.220"

        #vm.username = "755197"
        #vm.passwd = "zyh"

        vm.username = "827083"
        vm.passwd = "admin"

        #vm.username = "033638"
        #vm.passwd = "123"

        #vm.username = "admin"
        #vm.passwd = "admin"
        
        #vm.username = "314456"
        #vm.passwd = "123"

        #vm.username = "819865"
        #vm.passwd = "123"

        #vm.username = "415058"
        #vm.passwd = "admin"
        

        vm.submit = @submit
        vm.keypress = @keypress
        vm.close_alert = @close_alert
        vm.checked = false
        vm.show_ip = true

        vm.register_email = ""
        vm.register_name = ""
        vm.register_passwd = ""
        vm.register_confirm_passwd= ""
        vm.register_hotelname = ""
        vm.user_id = ""
        vm.forget_email = ""

        vm.QQlogin = @QQlogin
        vm.weixinlogin = @weixinlogin
        vm.weibologin = @weibologin

    rendered: () =>
        super()
        
        $.validator.addMethod "isLogined", (value, element) ->
            not (new SettingsManager).isLoginedMachine value
        $(".login-form").validate(
            valid_opt(
                rules:
                    device:
                        required: true
                        isLogined: true
                    username:
                        required: true
                    passwd:
                        required: true
                messages:
                    device:
                        required: "请输入存储IP"
                        isLogined: "您已经登录该设备"
                    username:
                        required: "请输入用户名"
                    passwd:
                        required: "请输入密码"
                errorPlacement: (error, elem) ->
                    error.addClass("help-small no-left-padding").
                        insertAfter(elem.closest(".input-icon"))))
                        
        $("#login-ip").typeahead(
            source: @_settings.getUsedMachines()
            items: 6
            updater: (item) =>
                @vm.device = item
        )
        
        ###@backstretch = $(".login").backstretch([
            "images/login-bg/1.png",
            "images/login-bg/2.jpg",
            "images/login-bg/3.jpg",
            "images/login-bg/4.jpg",
            ], fade: 1000, duration: 5000).data "backstretch"###

        @particles(this)
        @initpage(this)
        #@nivo()

        new PCAS('location_p', 'location_c', 'location_a', '广东省', '', '')
        ###$('.hastip-login').poshytip(
            className: 'tip-twitter'
            showTimeout: 0
            alignTo: 'target'
            alignX: 'center'
            offsetY: 5
        )###

        ###
        #$("#location_p").chosen()
        #$("#location_c").chosen()
        #$("#location_a").chosen()

        $('#location_p_chzn a').attr('style', 'background-color: #DDE3EC;color: #8290A3;border: 1px solid #DDE3EC;height: 39px !important;width: 255px;');
        $('#location_c_chzn a').attr('style', 'background-color: #DDE3EC;color: #8290A3;border: 1px solid #DDE3EC;height: 39px !important;width: 255px;');
        $('#location_a_chzn a').attr('style', 'background-color: #DDE3EC;color: #8290A3;border: 1px solid #DDE3EC;height: 39px !important;width: 255px;');
        
        $('#location_p_chzn .chzn-search').attr('style', 'display:none');
        $('#location_c_chzn .chzn-search').attr('style', 'display:none');
        $('#location_a_chzn .chzn-search').attr('style', 'display:none');

        $('#location_p_chzn .chzn-drop').attr('style', 'width: 289px !important;');
        $('#location_c_chzn .chzn-drop').attr('style', 'width: 289px !important;');
        $('#location_a_chzn .chzn-drop').attr('style', 'width: 289px !important;');

        $('#location_p_chzn ul').attr('style', 'background-color: #DDE3EC;color: #8290A3;border: 1px solid #DDE3EC;width: 282px;');
        $('#location_c_chzn ul').attr('style', 'background-color: #DDE3EC;color: #8290A3;border: 1px solid #DDE3EC;width: 282px;');
        $('#location_a_chzn ul').attr('style', 'background-color: #DDE3EC;color: #8290A3;border: 1px solid #DDE3EC;width: 282px;');

        ###
        #@scroller()
        #@QQlogin()
        new WOW().init();
        return

    scroller:() =>
        $(`function() {
            (function($){
                $ (window).on("load",function(){
                    $("#page-scroller").mCustomScrollbar();
                });
            })(jQuery);
            
        }`)

    submit: () =>
        #window.location.href = "register_guide.html";
        port = @settings.port 
        if $(".login-form").validate().form()
            try
                @try_login = true
                code = sha256_digest( @vm.key + @vm.passwd + "/login");
                log_request = new SessionRest("#{@vm.device}:" + port).login @vm.username, code
                log_request.done (data) =>
                    if data.status is "failed"
                        if data.detail is "account online"
                            (new MessageModal lang.login.online_error).attach()
                        else
                            (new MessageModal lang.login.passwd_error).attach()
                    else
                        @dview.token = data.detail
                        @dview.user_name = data.detail
                        isLogined = false
                        login_machine = ""
                        settings = new SettingsManager
                        @_login()
                log_request.fail =>
                    (new MessageModal lang.login.link_error).attach()
            catch e
                return
        
                
    _login: () =>
        port = @settings.port
        chain = new Chain
        chain.chain @dview.init @vm.device, @vm.username
        show_chain_progress(chain, true).done(=>
            #$('#user_head').attr('style', 'display:block');
            #$('#user_setting').attr('style', 'display:block');
            @head = new HeaderUI(@sd,"store")
            @head.avatar("#{@vm.device}:" + port,@vm.username)
            @dview.attach()
        ).fail(=>
            (new MessageModal "初始化失败").attach()
            @dview.attach())
                            
    ###submit: () =>
        chain = new Chain
        chain.chain @dview.init @vm.device
        show_chain_progress(chain, true).done(=>
            @dview.attach()
            
        ).fail(=>
            @dview.attach()) ###  
            
    QQlogin:() =>
        $(`function(){
            QC.Login({
               btnId:"qqLoginBtn",    
               scope:"all",
               size: "A_XL"
            }, function(reqData, opts){
               //根据返回数据，更换按钮显示状态方法
               var dom = document.getElementById(opts['btnId']),
               _logoutTemplate=[
                    //头像
                    '<span><img src="{figureurl}" class="{size_key}"/></span>',
                    //昵称
                    '<span>{nickname}</span>',
                    //退出
                    '<span><a href="javascript:QC.Login.signOut();">退出</a></span>'    
               ].join("");
               dom && (dom.innerHTML = QC.String.format(_logoutTemplate, {
                   nickname : QC.String.escHTML(reqData.nickname), //做xss过滤
                   figureurl : reqData.figureurl
               }));
            }, function(opts){//注销成功
                 alert('QQ登录 注销成功');
            });
        }`)

    weixinlogin:()=>
        return

    weibologin:()=>
        return

    tips:(sd) =>
        try
            info = []
            datas = {}
            type = {}
            for i in sd.centers.items
                info.push i.Ip
                datas[i.Ip] = 0
                type[i.Ip] = i.Devtype
                
            ((datas[j.ip] = datas[j.ip] + 1 )for j in sd.stores.items.journals when j.ip in info)
            for k in info
                if datas[k] > 0
                    if type[k] is "storage"
                        types = "存储"
                    else
                        types = "服务器"
                    @show_tips(k,datas[k],types)
        catch e
            console.log e
                
    show_tips:(ip,num,type) =>
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
                text: '<a href="#" style="color:#ccc;font-size:14px;">' + type + ip + '有' + num + '条告警信息</a><br>点击可查看.'
            });
            return false;
        }`)

    particles: (page) =>
        $(`function() {
            particlesJS("particles-js", {
              "particles": {
                "number": {
                  "value": 70,
                  "density": {
                    "enable": true,
                    "value_area": 800
                  }
                },
                "color": {
                  "value": "#ffffff"
                },
                "shape": {
                  "type": "circle",
                  "stroke": {
                    "width": 0,
                    "color": "#000000"
                  },
                  "polygon": {
                    "nb_sides": 5
                  },
                  "image": {
                    "src": "img/github.svg",
                    "width": 100,
                    "height": 100
                  }
                },
                "opacity": {
                  "value": 0.5,
                  "random": false,
                  "anim": {
                    "enable": false,
                    "speed": 1,
                    "opacity_min": 0.1,
                    "sync": false
                  }
                },
                "size": {
                  "value": 3,
                  "random": true,
                  "anim": {
                    "enable": false,
                    "speed": 40,
                    "size_min": 0.1,
                    "sync": false
                  }
                },
                "line_linked": {
                  "enable": true,
                  "distance": 150,
                  "color": "#ffffff",
                  "opacity": 0.4,
                  "width": 1
                },
                "move": {
                  "enable": true,
                  "speed": 0.1,
                  "direction": "none",
                  "random": false,
                  "straight": false,
                  "out_mode": "out",
                  "bounce": false,
                  "attract": {
                    "enable": false,
                    "rotateX": 600,
                    "rotateY": 1200
                  }
                }
              },
              "interactivity": {
                "detect_on": "canvas",
                "events": {
                  "onhover": {
                    "enable": false,
                    "mode": "grab"
                  },
                  "onclick": {
                    "enable": false,
                    "mode": "push"
                  },
                  "resize": true
                },
                "modes": {
                  "grab": {
                    "distance": 140,
                    "line_linked": {
                      "opacity": 1
                    }
                  },
                  "bubble": {
                    "distance": 400,
                    "size": 30,
                    "duration": 2,
                    "opacity": 8,
                    "speed": 3
                  },
                  "repulse": {
                    "distance": 200,
                    "duration": 0.4
                  },
                  "push": {
                    "particles_nb": 4
                  },
                  "remove": {
                    "particles_nb": 2
                  }
                }
              },
              "retina_detect": true
            });
        }`)

    initpage: (page) =>
        $(`function() {
            $('.forget-form').validate({
                errorElement: 'label', //default input error message container
                errorClass: 'help-inline', // default input error message class
                focusInvalid: false, // do not focus the last invalid input
                ignore: "",
                rules: {
                    email: {
                        required: true,
                        email: true
                    }
                },

                messages: {
                    email: {
                        required: "邮箱不能为空"
                    }
                },

                invalidHandler: function (event, validator) { //display error alert on form submit   

                },

                highlight: function (element) { // hightlight error inputs
                    $(element)
                        .closest('.control-group').addClass('error'); // set error class to the control group
                },

                success: function (label) {
                    label.closest('.control-group').removeClass('error');
                    label.remove();
                },

                errorPlacement: function (error, element) {
                    error.addClass('help-small no-left-padding').insertAfter(element.closest('.input-icon'));
                },

                submitHandler: function (form) {
                    var machine_detail, query;
                    var port = page.settings.port;
                    query = new SessionRest(page.vm.device + ":" + port);
                    machine_detail = query.forget(page.vm.forget_email);
                    machine_detail.done(function(data) {
                      if (data.status === "success") {
                            jQuery('.forget-form').hide();
                            return jQuery('.forget-success-form').show();
                      } else {
                        return (new MessageModal(page.vm.lang.forget_email_error)).attach();
                        }
                    });
                    return machine_detail.fail(function() {
                      return (new MessageModal(page.vm.lang.link_error)).attach();
                    });
                }
            });

            jQuery('#forget-back-btn').click(function () {
                window.location.href = "index.html";
            });

            $('.forget-form input').keypress(function (e) {
                if (e.which == 13) {
                    if ($('.forget-form').validate().form()) {
                        window.location.href = "index.html";
                    }
                    return false;
                }
            });

            jQuery('#forget-password').click(function () {
                jQuery('.login-form').hide();
                jQuery('.forget-form').show();
            });

            jQuery('#back-btn').click(function () {
                jQuery('.login-form').show();
                jQuery('.forget-form').hide();
            });

            $('.register-form').validate({
                errorElement: 'label', //default input error message container
                errorClass: 'help-inline', // default input error message class
                focusInvalid: false, // do not focus the last invalid input
                ignore: "",
                rules: {
                    username: {
                        required: true
                    },
                    password: {
                        required: true
                    },
                    rpassword: {
                        equalTo: "#register_password"
                    },
                    email: {
                        required: true,
                        email: true
                    },
                    tnc: {
                        required: true
                    },
                    location: {
                        required: true
                    }
                },

                messages: { // custom messages for radio buttons and checkboxes
                    tnc: {
                        required: "请勾选"
                    }
                },

                invalidHandler: function (event, validator) { //display error alert on form submit   

                },

                highlight: function (element) { // hightlight error inputs
                    $(element)
                        .closest('.control-group').addClass('error'); // set error class to the control group
                },

                success: function (label) {
                    label.closest('.control-group').removeClass('error');
                    label.remove();
                },

                errorPlacement: function (error, element) {
                    if (element.attr("name") == "tnc") { // insert checkbox errors after the container                  
                        error.addClass('help-small no-left-padding').insertAfter($('#register_tnc_error'));
                    } else {
                        error.addClass('help-small no-left-padding').insertAfter(element.closest('.input-icon'));
                    }
                },

                submitHandler: function (form) {
                    var selected_p = $("#location_p").val();
                    var selected_c = $("#location_c").val();
                    var selected_a = $("#location_a").val();

                    if (selected_a == "市辖区"){
                        return (new MessageModal(page.vm.lang.location_a_error)).attach();
                    }else{
                        var machine_detail, query;
                        var port = page.settings.port;
                        query = new SessionRest(page.vm.device + ":" + port);
                        machine_detail = query.register(page.vm.register_name,page.vm.register_passwd,page.vm.register_email,selected_p + selected_c + selected_a + page.vm.register_hotelname);
                        machine_detail.done(function(data) {
                          if (data.status === "success") {
                                page.vm.user_id = data.detail;
                                jQuery('.register-form').hide();
                                page.vm.username = data.detail;
                                page.vm.passwd = page.vm.register_passwd;
                                return jQuery('.wellcome-form').show();
                          } else {
                            return (new MessageModal(page.vm.lang.email_error)).attach();
                            }
                        });
                        return machine_detail.fail(function() {
                          return (new MessageModal(page.vm.lang.link_error)).attach();
                        });
                    }
                }
            });

            $('.wellcome-form').validate({
                submitHandler: function (form) {
                    page.submit();
                }
            });

            jQuery('#wellcome-back-btn').click(function () {
                window.location.href = "index.html";
            });

            jQuery('#register-btn').click(function () {
                jQuery('.login-form').hide();
                jQuery('.register-form').show();
            });

            jQuery('#register-back-btn').click(function () {
                jQuery('.login-form').show();
                jQuery('.register-form').hide();
            });
        }`)

    keypress: (e) =>
        @submit() if e.which is 13
        
    close_alert: (e) =>
        $(".alert-error").hide()
        
    _init_device: =>
        @try_login = false
        @_settings.addUsedMachine @vm.device
        @_settings.addLoginedMachine @vm.device
        @_settings.addSearchedMachine @vm.device
        return

class CentralServerViewPage extends Page
    constructor: (@sd, @switch_to_page) ->
        super "centralviewpage-", "html/centralserverviewpage.html"

        @flow_max = 0
        $(@sd.stats).on "updated", (e, source) =>
            if @has_rendered
                latest = source.items[source.items.length-1]
                @vm.cpu_load  = parseInt latest.server_cpu
                @vm.cache_load  = parseInt latest.server_system
                @vm.mem_load = parseInt latest.server_mem
                @refresh_num()
                #try
                #    @bubble parseInt(latest.server_cpu),parseInt(latest.server_system),parseInt(latest.server_mem)
                #catch e
                #    console.log e
                
                #@spark @sd.stats.items[0].exports.length,@_process()
                #@monitor(latest)
                #@vm.on_monitor = @_ping()
                #@plot_flow_in source.items
                #@plot_flow_out source.items
                #@sparkline_stats(latest.server_system,latest.temp,latest.server_cap)
                #@refresh_pie()
                
        $(@sd.journals).on "updated", (e, source) =>
            @vm.journal = @subitems()
            
        $(@sd.centers).on "updated", (e, source) =>
            num = []
            ((num.push i) for i in source.items when i.Devtype is "export" and i.Status)
            @vm.on_monitor = num.length
            
    define_vm: (vm) =>
        vm.lang = lang.central_server_view
        vm.cpu_load = 0
        vm.cache_load = 0
        vm.mem_load = 0
        vm.colony_num = 0
        vm.machine_num = 0
        vm.warning_num = 0
        vm.process_num = 0
        vm.total_monitor = 0
        vm.on_monitor = 0
        vm.clear_log = @clear_log
        vm.status_server = "normal"
        vm.change_status = @change_status
        vm.journals = []
        vm.flow_type = "fwrite_mb"
        vm.rendered = @rendered
        vm.fattr_journal_status = fattr.journal_status
        vm.fattr_monitor_status = fattr.monitor_status
        vm.fattr_view_status_fixed = fattr.view_status_fixed
        vm.switch_to_page = @switch_to_page
        
        vm.journal = @subitems()
        vm.journal_info = @subitems_info()
        vm.journal_warning = @subitems_warning()
        vm.journal_critical = @subitems_critical()
        vm.rendered = @rendered
        vm.detail_cpu = @detail_cpu
        vm.detail_cache = @detail_cache
        vm.detail_mem = @detail_mem
        vm.handle_log = @handle_log
        
    rendered: () =>
        super()
        @vm.journal = @subitems()
        @vm.journal_info = @subitems_info()
        @vm.journal_warning = @subitems_warning()
        @vm.journal_critical = @subitems_critical()
        @data_table1 = $("#log-table1").dataTable dtable_opt(retrieve: true, bSort: false,scrollX: true)
        @data_table2 = $("#log-table2").dataTable dtable_opt(retrieve: true, bSort: false,scrollX: true)
        @data_table3 = $("#log-table3").dataTable dtable_opt(retrieve: true, bSort: false,scrollX: true)
        @data_table4= $("#log-table4").dataTable dtable_opt(retrieve: true, bSort: false,scrollX: true)
        $(".dataTables_filter input").addClass "m-wrap small"
        $(".dataTables_length select").addClass "m-wrap small"
        $('.countup').counterUp({delay: 2,time: 1000})
        $scroller1 = $("#journals-scroller-1")
        $scroller2 = $("#journals-scroller-2")
        $scroller3 = $("#journals-scroller-3")
        $scroller4 = $("#journals-scroller-4")
        
        $scroller1.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller1.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
        $scroller2.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller2.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
        $scroller3.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller3.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
        $scroller4.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller4.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
            
        try
            @plot_flow_in @sd.stats.items
        catch e
            console.log e
        @refresh_num()
        @bubble @sd.stats.items
    
        #@process_stats()
        #@sparkline_stats 50
        #@update_circle()
        #$('.tooltips').tooltip()
        #$("#count1").addClass "animated zoomIn"
        #$("#count2").addClass "animated zoomIn"
        #$("#count3").addClass "animated zoomIn"
        #$("#count4").addClass "animated zoomIn"
        #$('#count1').counterUp({delay: 3,time: 1000})
        #$(".dataTables_filter select").css({ background: "url('images/chosen-sprite.png')"})
        #@calendar()
        #@spark 1,2
        #@flot_cpu @sd.stats.items
        #@flot_mem @sd.stats.items
        #@flot_cache @sd.stats.items
        #@plot_flow_out @sd.stats.items
        
    subitems: () =>
        try
            arrays = []
            for i in @sd.journals.items
                i.created = i.created.replace("-","/").replace("-","/").replace("T","-").replace("+08:00","")
                if i.status
                    i.chinese_status = "已处理"
                else
                    i.chinese_status = "未处理"
                arrays.push i
            arrays.reverse()
        catch error
            return []
        
    subitems_info: () =>
        info = []
        ((info.push i) for i in @subitems() when i.level is 'info')
        info
            
    subitems_warning: () =>
        info = []
        ((info.push i) for i in @subitems() when i.level is 'warning')
        info
            
    subitems_critical: () =>
        info = []
        ((info.push i) for i in @subitems() when i.level is 'critical')
        info
        
    refresh_num: () =>
        @vm.colony_num = @_colony()
        @vm.machine_num = @_machine()
        @vm.warning_num = @_warning()
        @vm.process_num = @_process()
        
    handle_log:() =>
        (new CentralHandleLogModal(@sd, this)).attach()
        
    bubble : (items) =>
        $(`function (){
            var config1 = liquidFillGaugeDefaultSettings();
            var config2 = liquidFillGaugeDefaultSettings();
            var config3 = liquidFillGaugeDefaultSettings();
            
            config1.waveAnimateTime = 1000;
            config2.waveAnimateTime = 1000;
            config3.waveAnimateTime = 1000;
            
            config1.textVertPosition = 0.8;
            config2.textVertPosition = 0.8;
            config3.textVertPosition = 0.8;
            
            config1.textSize = 0.55;
            config2.textSize = 0.55;
            config3.textSize = 0.55;
            
            config1.textColor = "rgba(0,0,0,0)";
            config2.textColor = "rgba(0,0,0,0)";
            config3.textColor = "rgba(0,0,0,0)";
            
            config1.circleColor = "rgb(87, 199, 212)";
            config2.circleColor = "rgb(98, 168, 234)";
            config3.circleColor = "rgb(146, 109, 222)";
            
            config1.waveColor = "rgba(87, 199, 212,0.8)";
            config2.waveColor = "rgba(98, 168, 234,0.8)";
            config3.waveColor = "rgba(146, 109, 222,0.8)";
            
            config1.circleFillGap = 0;
            config2.circleFillGap = 0;
            config3.circleFillGap = 0;
            
            var gauge1 = loadLiquidFillGauge("fillgauge1", 0, config1);
            var gauge2 = loadLiquidFillGauge("fillgauge2", 0, config2);
            var gauge3 = loadLiquidFillGauge("fillgauge3", 0, config3);
            
            setInterval(function () {
                try{
                    var cpu = items[items.length - 1].server_cpu;
                        system = items[items.length - 1].server_system;
                        mem = items[items.length - 1].server_mem;
                    gauge1.update(cpu);
                    gauge2.update(system);
                    gauge3.update(mem);
                }
                catch(e){
                    console.log(e);
                }
            }, 3000);
        }`);
        ###config.circleThickness = 0.15;
            config.circleColor = "#808015";
            config.textColor = "#fff";
            config.waveTextColor = "#FFF";
            config.waveColor = "#AAAA39";
            config.textVertPosition = 0.8;
            config.waveAnimateTime = 1000;
            config.waveHeight = 0.05;
            config.waveAnimate = true;
            config.waveRise = false;
            config.waveHeightScaling = false;
            config.waveOffset = 0.25;
            config.textSize = 0.75;
            config.waveCount = 3;
            var config1 = config;
            var config2 = config;
            var config3 = config;
            ###
            
    spark: (total,online) =>
        $(`function() {  
            $("#sparkline1").sparkline([online,total-online], {
                type: 'pie',
                width: '110',
                height: '110',
                borderColor: '#',
                sliceColors: ['rgb(227, 91, 90)','rgba(227, 91, 90,0.5)']})
            $("#sparkline2").sparkline([5,6,7,9,9,5,3,2,2,4,6,7], {
                type: 'line',
                width: '200px',
                height: '50px',
                lineColor: '#0000ff'});
            $("#sparkline3").sparkline([5,6,7,9,9,5,3,2,2,4,6,7], {
                type: 'line',
                width: '150px',
                height: '50px',
                lineColor: '#0000ff'});
            $('#sparkline1').bind('sparklineRegionChange', function(ev) {
                var sparkline = ev.sparklines[0],
                    region = sparkline.getCurrentRegionFields(),
                    value = region.percent;
                $('.mouseoverregion').text("使用率:" + value);
            }).bind('mouseleave', function() {
                $('.mouseoverregion').text('');
            });
        }`)
        
    _ping: () =>
        num = []
        ((num.push i) for i in @sd.centers.items when i.Devtype is "export" and i.Status)
        num.length
        
    _colony: () =>
        option = [0]
        ((option.push i.cid) for i in @sd.clouds.items when i.cid not in option and i.devtype is "storage")
        max = Math.max.apply(null,option)
        max
        
    _machine: () =>
        option = []
        ((option.push i.cid) for i in @sd.clouds.items when i.devtype is "export")
        option.length
        
    _warning: () =>
        arrays = []
        for i in @sd.journals.items
            if i.level is "warning" or i.level is "critical"
                if !i.status
                    arrays.push i
        arrays.length
        
    _process: () =>
        if @sd.centers.items != null
            tmp = []
            items = subitems @sd.centers.items, Uuid:"", Ip:"", Slotnr:"", Created: "",Devtype:""
            ((tmp.push i) for i in items when i.Devtype is "export")
            tmp.length
            
    update_circle: () =>
        opt1 = animate: 1000, size: 100, lineWidth: 5, lineCap: "butt", barColor: "rgb(87, 199, 212)",trackColor: 'rgba(87, 199, 212,0.1)',scaleColor: false
        opt2 = animate: 1000, size: 100, lineWidth: 5, lineCap: "butt", barColor: "rgb(98, 168, 234)",trackColor: 'rgba(98, 168, 234,0.1)',scaleColor: false
        opt3 = animate: 1000, size: 100, lineWidth: 5, lineCap: "butt", barColor: "rgb(146, 109, 222)",trackColor: 'rgba(146, 109, 222,0.1)',scaleColor: false
        try
            $("#cpu-load").easyPieChart opt1
            $("#cpu-load").data("easyPieChart").update? @vm.cpu_load
            $("#cache-load").easyPieChart opt2
            $("#cache-load").data("easyPieChart").update? @vm.cache_load
            $("#mem-load").easyPieChart opt3
            $("#mem-load").data("easyPieChart").update? @vm.mem_load
        catch e
            console.log e
            
    change_status: (type) =>
        @vm.status_server = type
        
    clear_log:() =>
        if @vm.journal.length is 0
            (new MessageModal @vm.lang.clear_log_error).attach()
            return
        (new ConfirmModal(@vm.lang.clear_log_tips, =>
            @frozen()
            chain = new Chain()
            chain.chain(=> (new JournalRest(@sd.host)).delete_log())
            chain.chain @sd.update("all")
            show_chain_progress(chain).done =>
                @attach()
                (new MessageModal @vm.lang.clear_log_success).attach()
        )).attach()
        
    detail_cpu: () =>
        (new CentralServerCpuModal(@sd, this)).attach()
    
    detail_cache: () =>
        return
        #(new CentralServerCacheModal(@sd, this)).attach()
        
    detail_mem: () =>
        (new CentralServerMemModal(@sd, this)).attach()
        
    add_time_to_journal:(items) =>
        journals = []
        change_time = `function funConvertUTCToNormalDateTime(utc)
        {
            var date = new Date(utc);
            var ndt;
            ndt = date.getFullYear()+"/"+(date.getMonth()+1)+"/"+date.getDate()+"-"+date.getHours()+":"+date.getMinutes()+":"+date.getSeconds();
            return ndt;
        }`
        for item in items
            item.date = change_time(item.created_at*1000)
            journals.push item
        
        return journals
        
    calendar: () =>
        $(document).ready(`function() {
            $('#calendar').fullCalendar({
            })
        }`)
        
    sparkline_stats: (rate) =>
        return
        arm =
            chart: 
                type: 'pie'
                margin: [0, 0, 0, 0]
            title: 
                text: ''
                verticalAlign: "bottom"
                style: 
                    color: '#000'
                    fontFamily: 'Microsoft YaHei'
                    fontSize:16
            subtitle: 
                text: ''
            xAxis:
                type: 'category'
                gridLineColor: '#FFF'
                tickColor: '#FFF'
                labels: 
                    enabled: false
                    rotation: -45
                    style: 
                        fontSize: '13px'
                        fontFamily: 'opensans-serif'
            yAxis: 
                gridLineColor: '#FFF'
                min: 0
                max:100
                title: 
                    text: ''
                labels: 
                    enabled: true
            credits: 
                enabled:false
            exporting: 
                enabled: false
            legend: 
                enabled: true
            tooltip:
                pointFormat: '<b>{point.y:.1f}%</b>'
                style: 
                    color:'#fff'
                    fontSize:'12px'
                    opacity:0.8
                borderRadius:0
                borderColor:'#000'
                backgroundColor:'#000'
            plotOptions: 
                pie: 
                    animation:false,
                    shadow: false,
                    dataLabels: 
                        enabled: false
                    showInLegend: true
            series: [{
                type: 'pie'
                name: 'Population'
            }]

        $('#sparkline1').highcharts(Highcharts.merge(arm,
            title: 
                text: ''
            colors: ["rgb(40, 183, 121)", "rgba(40, 183, 121,0.5)"]
            series: [{
                name: '系统空间',
                data: [
                    ['已用',   rate*100],
                    ['剩余',   100 - rate*100]
                ]
            }]
        ))
        
    refresh_pie: () =>
        try
            data = []
            latest = @sd.stats.items[@sd.stats.items.length-1]
            ((data.push {name:i.protype,y:i.cpu}) for i in latest.master.process when i.cpu is 0)
            @process_stats data
        catch e
            console.log e
            
    process_stats: () =>
        ###Highcharts.getOptions().plotOptions.pie.colors = (`function () {
            var colors = [],
                base = Highcharts.getOptions().colors[0],
                i;
            for (i = 0; i < 10; i += 1) {
                // Start out with a darkened base color (negative brighten), and end
                // up with a much brighter color
                colors.push(Highcharts.Color(base).brighten((i - 3) / 7).get());
            }
            return colors;
        }()`)###
        $('#process_stats').highcharts(
            chart: 
                plotBackgroundColor: null
                plotBorderWidth: null
                plotShadow: false
                animation: false
                spacingBottom:50
            title: 
                text: '进程cpu占用率'
                verticalAlign: 'bottom'
            tooltip: 
                pointFormat: '{series.name}: <b>{point.percentage:.1f}%</b>'
            credits: 
                enabled:false
            legend: 
                enabled: false
            exporting: 
                enabled: false
            plotOptions: 
                pie: 
                    allowPointSelect: true
                    cursor: 'pointer'
                    dataLabels: 
                        enabled: false
                        format: '<b>{point.name}</b>: {point.percentage:.1f} %'
                        style: 
                            color: (Highcharts.theme && Highcharts.theme.contrastTextColor) || 'black'
                        connectorColor: 'silver'
            colors: ["rgba(3, 110, 184,1)","rgba(3, 110, 184,0.8)","rgba(3, 110, 184,0.6)","rgba(3, 110, 184,0.4)","rgba(3, 110, 184,0.2)","rgba(3, 110, 184,0.1)"],
            series: [{
                type: 'pie',
                name: '占用比率',
                data: [
                    ['minio',   45.0],
                    ['python',       26.8],
                    {
                        name: 'Chrome',
                        y: 12.8,
                        sliced: true,
                        selected: true
                    },
                    ['bash',    8.5],
                    ['ssh',     6.2],
                    ['access',   0.7]
                ]
            }])
            
    flot_cpu: (yaxis) =>
        $(document).ready(`function () {
            Highcharts.setOptions({
                global: {
                    useUTC: false
                }
            });
            var chart = Highcharts.chart('flot_cpu', {
                chart: {
                    type: 'areaspline',
                    //animation:false,
                    margin:[0,0,0,0],
                    width:200,
                    backgroundColor: 'rgba(0,0,0,0)',
                    animation: Highcharts.svg, // don't animate in old IE
                    marginRight: 10,
                    //plotBorderColor:"rgb(235, 235, 235)",
                    //plotBorderWidth:1,
                    //backgroundColor:"rgb(250, 250, 250)",
                    events: {
                        load: function () {
                            var series1 = this.series[0];
                            setInterval(function () {
                                try{
                                    var type1 = 'server_cpu';
                                    var x = (new Date()).getTime(), // current time
                                        y1 = yaxis[yaxis.length - 1][type1];
                                        y2 = Math.random()
                                    series1.addPoint([x, y1+y2], true, true);
                                }
                                catch(e){
                                    console.log(e);
                                }
                            }, 3000);
                        }
                    }
                },
                title: {
                    text: ''
                },
                xAxis: {
                    tickWidth: 0,
                    lineWidth: 0,
                    labels: {
                        enabled: false
                    },
                    type: 'datetime',
                    tickPixelInterval: 150
                },
                yAxis: {
                    labels:{
                        enabled:false
                    },
                    gridLineWidth:0,
                    min:-1,
                    //max:150,
                    title: {
                        text: ''
                    },
                    plotLines: [{
                        value: 0,
                        width: 0,
                        color: '#808080'
                    }]
                },
                tooltip: {
                    formatter: function () {
                        return Highcharts.numberFormat(this.y, 2);
                    },
                    style: {
                        color:'#fff',
                        fontSize:'12px',
                        opacity:0.8
                    },
                    borderRadius:0,
                    borderColor:'#000',
                    backgroundColor:'#000',
                },
                credits: {
                    enabled:false
                },
                legend: {
                    enabled: false
                },
                exporting: {
                    enabled: false
                },
                colors:["#62a8ea","#a58add"],
                plotOptions: {
                    areaspline: {
                        lineColor: "rgb(87, 199, 212)",
                        lineWidth:2,
                        fillColor: "#fff",
                        threshold: null,
                        animation:false,
                        states: {
                            hover: {
                                lineWidth: 1
                            }
                        },
                        marker: {
                            enabled: true,
                            symbol: 'circle',
                            radius: 1,
                            lineWidth:1,
                            lineColor:"#fff",
                            fillColor:"rgba(165, 138, 221,0.6)"
                        },
                        fillOpacity:0.3
                    }
                },
                series: [{
                    name: '写流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            for (i = -9; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    y: Math.random()
                                });
                            }
                            return data;
                        }
                        catch(e){
                            console.log(e);
                        }
                    }())
                }]
            });
        }`);
        
    flot_cache: (yaxis) =>
        $(document).ready(`function () {
            Highcharts.setOptions({
                global: {
                    useUTC: false
                }
            });
            var chart = Highcharts.chart('flot_cache', {
                chart: {
                    type: 'areaspline',
                    //animation:false,
                    margin:[0,0,0,0],
                    width:200,
                    backgroundColor: 'rgba(0,0,0,0)',
                    animation: Highcharts.svg, // don't animate in old IE
                    marginRight: 10,
                    //plotBorderColor:"rgb(235, 235, 235)",
                    //plotBorderWidth:1,
                    //backgroundColor:"rgb(250, 250, 250)",
                    events: {
                        load: function () {
                            var series1 = this.series[0];
                            setInterval(function () {
                                try{
                                    var type1 = 'server_cache';
                                    var x = (new Date()).getTime(), // current time
                                        y1 = yaxis[yaxis.length - 1][type1];
                                        y2 = Math.random()
                                    series1.addPoint([x, y1+y2], true, true);
                                }
                                catch(e){
                                    console.log(e);
                                }
                            }, 3000);
                        }
                    }
                },
                title: {
                    text: ''
                },
                xAxis: {
                    tickWidth: 0,
                    lineWidth: 0,
                    labels: {
                        enabled: false
                    },
                    type: 'datetime',
                    tickPixelInterval: 150
                },
                yAxis: {
                    labels:{
                        enabled:false
                    },
                    gridLineWidth:0,
                    min:-1,
                    //max:150,
                    title: {
                        text: ''
                    },
                    plotLines: [{
                        value: 0,
                        width: 0,
                        color: '#808080'
                    }]
                },
                tooltip: {
                    formatter: function () {
                        return Highcharts.numberFormat(this.y, 2);
                    },
                    style: {
                        color:'#fff',
                        fontSize:'12px',
                        opacity:0.8
                    },
                    borderRadius:0,
                    borderColor:'#000',
                    backgroundColor:'#000',
                },
                credits: {
                    enabled:false
                },
                legend: {
                    enabled: false
                },
                exporting: {
                    enabled: false
                },
                colors:["#62a8ea","#a58add"],
                plotOptions: {
                    areaspline: {
                        lineColor: "rgb(98, 168, 234)",
                        lineWidth:2,
                        fillColor: "#fff",
                        threshold: null,
                        animation:false,
                        states: {
                            hover: {
                                lineWidth: 1
                            }
                        },
                        marker: {
                            enabled: true,
                            symbol: 'circle',
                            radius: 1,
                            lineWidth:1,
                            lineColor:"#fff",
                            fillColor:"rgba(165, 138, 221,0.6)"
                        },
                        fillOpacity:0.3
                    }
                },
                series: [{
                    name: '写流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            for (i = -9; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    y: Math.random()
                                });
                            }
                            return data;
                        }
                        catch(e){
                            console.log(e);
                        }
                    }())
                }]
            });
        }`);
        
    flot_mem: (yaxis) =>
        $(document).ready(`function () {
            Highcharts.setOptions({
                global: {
                    useUTC: false
                }
            });
            var chart = Highcharts.chart('flot_mem', {
                chart: {
                    type: 'areaspline',
                    //animation:false,
                    margin:[0,0,0,0],
                    width:200,
                    backgroundColor: 'rgba(0,0,0,0)',
                    animation: Highcharts.svg, // don't animate in old IE
                    marginRight: 10,
                    //plotBorderColor:"rgb(235, 235, 235)",
                    //plotBorderWidth:1,
                    //backgroundColor:"rgb(250, 250, 250)",
                    events: {
                        load: function () {
                            var series1 = this.series[0];
                            setInterval(function () {
                                try{
                                    var type1 = 'server_mem';
                                    var x = (new Date()).getTime(), // current time
                                        y1 = yaxis[yaxis.length - 1][type1];
                                        y2 = Math.random();
                                    series1.addPoint([x, y1+y2], true, true);
                                }
                                catch(e){
                                    console.log(e);
                                }
                            }, 3000);
                        }
                    }
                },
                title: {
                    text: ''
                },
                xAxis: {
                    tickWidth: 0,
                    lineWidth: 0,
                    labels: {
                        enabled: false
                    },
                    type: 'datetime',
                    tickPixelInterval: 150
                },
                yAxis: {
                    labels:{
                        enabled:false
                    },
                    gridLineColor: "#FFF",
                    min:-1,
                    //max:150,
                    title: {
                        text: ''
                    },
                    plotLines: [{
                        value: 0,
                        width: 0,
                        color: '#808080'
                    }]
                },
                tooltip: {
                    formatter: function () {
                        return Highcharts.numberFormat(this.y, 2);
                    },
                    style: {
                        color:'#fff',
                        fontSize:'12px',
                        opacity:0.8
                    },
                    borderRadius:0,
                    borderColor:'#000',
                    backgroundColor:'#000',
                },
                credits: {
                    enabled:false
                },
                legend: {
                    enabled: false
                },
                exporting: {
                    enabled: false
                },
                colors:["#62a8ea","#a58add"],
                plotOptions: {
                    areaspline: {
                        lineColor: "rgb(146, 109, 222)",
                        lineWidth:2,
                        fillColor: "#fff",
                        threshold: null,
                        animation:false,
                        states: {
                            hover: {
                                lineWidth: 1
                            }
                        },
                        marker: {
                            enabled: false,
                            symbol: 'circle',
                            radius: 1,
                            lineWidth:1,
                            lineColor:"#fff",
                            fillColor:"rgba(255,120,120)"
                        },
                        fillOpacity:0.3
                    }
                },
                series: [{
                    name: '写流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            for (i = -9; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    y: Math.random()
                                });
                            }
                            return data;
                        }
                        catch(e){
                            console.log(e);
                        }
                    }())
                }]
            });
        }`);
    plot_flow_in: (yaxis) =>
        $(document).ready(`function () {
            Highcharts.setOptions({
                global: {
                    useUTC: false
                }
            });
            var chart = Highcharts.chart('flow_stats_in', {
                chart: {
                    type: 'areaspline',
                    //animation:false,
                    animation: Highcharts.svg, // don't animate in old IE
                    marginRight: 10,
                    //plotBorderColor:"rgb(235, 235, 235)",
                    //plotBorderWidth:1,
                    //backgroundColor:"rgb(250, 250, 250)",
                    events: {
                        load: function () {
                            var series1 = this.series[0];
                            var series2 = this.series[1];
                            setInterval(function () {
                                try{
                                    var type1 = 'server_net_write';
                                    var type2 = 'server_net_read';
                                    var random = Math.random();
                                    var x = (new Date()).getTime(), // current time
                                        y1 = yaxis[yaxis.length - 1][type1];
                                        y2 = yaxis[yaxis.length - 1][type2];
                                    series1.addPoint([x, y1 + random], true, true);
                                    series2.addPoint([x, y2 + random], true, true);
                                }
                                catch(e){
                                    console.log(e);
                                }
                            }, 3000);
                            series2.hide();
                        }
                    }
                },
                title: {
                    text: ''
                },
                xAxis: {
                    tickWidth: 0,
                    labels: {
                        enabled: false
                    },
                    type: 'datetime',
                    tickPixelInterval: 150
                },
                yAxis: {
                    maxPadding: 2,
                    tickAmount: 4,
                    gridLineColor: "#FFF",
                    min:-1,
                    //max:150,
                    title: {
                        text: ''
                    },
                    plotLines: [{
                        value: 0,
                        width: 0,
                        color: '#808080'
                    }]
                },
                tooltip: {
                    formatter: function () {
                        return '<b>' + this.series.name + '</b><br/>' +
                            Highcharts.dateFormat('%Y-%m-%d %H:%M:%S', this.x) + '<br/>' +
                            Highcharts.numberFormat(this.y, 2);
                    },
                    style: {
                        color:'#fff',
                        fontSize:'12px',
                        opacity:0.8
                    },
                    borderRadius:0,
                    borderColor:'#000',
                    backgroundColor:'#000',
                },
                credits: {
                    enabled:false
                },
                legend: {
                    enabled: false
                },
                exporting: {
                    enabled: false
                },
                colors:["#62a8ea","#a58add"],
                plotOptions: {
                    areaspline: {
                        threshold: null,
                        animation:false,
                        states: {
                            hover: {
                                lineWidth: 1
                            }
                        },
                        marker: {
                            enabled: false,
                            symbol: 'circle',
                            radius: 1,
                            lineWidth:1,
                            lineColor:"#fff",
                            fillColor:"rgba(255,120,120)"
                        },
                        fillOpacity:0.3
                    }
                },
                series: [{
                    name: '写流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            for (i = -9; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    y: Math.random()
                                });
                            }
                            return data;
                        }
                        catch(e){
                            console.log(e);
                        }
                    }())
                },{
                    name: '读流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            for (i = -9; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    y: Math.random()
                                });
                            }
                            return data;
                        }
                        catch(e){
                            console.log(e);
                        }
                    }())
                }]
            });
            $('#net_write').click(function () {
                var series1 = chart.series[0];
                var series2 = chart.series[1];
                series1.show();
                series2.hide();
            });
            $('#net_read').click(function () {
                var series1 = chart.series[0];
                var series2 = chart.series[1];
                series1.hide();
                series2.show();
            });
        }`);

    plot_flow_out: (yaxis) =>
        $(document).ready(`function () {
            Highcharts.setOptions({
                global: {
                    useUTC: false
                }
            });
            var chart = Highcharts.chart('flow_stats_out', {
                chart: {
                    type: 'areaspline',
                    //animation:false,
                    animation: Highcharts.svg, // don't animate in old IE
                    marginRight: 10,
                    plotBorderColor:"rgb(235, 235, 235)",
                    plotBorderWidth:1,
                    //backgroundColor:"rgb(250, 250, 250)",
                    events: {
                        load: function () {
                            var series1 = this.series[0];
                            var series2 = this.series[1];
                            setInterval(function () {
                                try{
                                    var type1 = 'server_vol_write';
                                    var type2 = 'server_vol_read';
                                    var random = Math.random();
                                    var x = (new Date()).getTime(), // current time
                                        y1 = yaxis[yaxis.length - 1][type1];
                                        y2 = yaxis[yaxis.length - 1][type2];
                                    series1.addPoint([x, y1 + random], true, true);
                                    series2.addPoint([x, y2 + random], true, true);
                                }
                                catch(e){
                                    console.log(e);
                                }
                            }, 3000);
                            series2.hide();
                        }
                    }
                },
                title: {
                    text: ''
                },
                xAxis: {
                    tickWidth: 0,
                    labels: {
                        enabled: false
                    },
                    type: 'datetime',
                    tickPixelInterval: 150
                },
                yAxis: {
                    gridLineColor: "#FFF",
                    min:-1,
                    title: {
                        text: ''
                    },
                    plotLines: [{
                        value: 0,
                        width: 1,
                        color: '#808080'
                    }]
                },
                tooltip: {
                    formatter: function () {
                        return '<b>' + this.series.name + '</b><br/>' +
                            Highcharts.dateFormat('%Y-%m-%d %H:%M:%S', this.x) + '<br/>' +
                            Highcharts.numberFormat(this.y, 2);
                    },
                    style: {
                        color:'#fff',
                        fontSize:'12px',
                        opacity:0.8
                    },
                    borderRadius:0,
                    borderColor:'#000',
                    backgroundColor:'#000'
                },
                credits: {
                    enabled:false
                },
                legend: {
                    enabled: false
                },
                exporting: {
                    enabled: false
                },
                plotOptions: {
                    areaspline: {
                        threshold: null,
                        animation:false,
                        states: {
                            hover: {
                                lineWidth: 2
                            }
                        },
                        fillOpacity: 0.2,
                        marker: {
                            enabled: true,
                            symbol: 'circle',
                            radius: 4.5,
                            fillColor:"rgb(143, 208, 253)",
                            states: {
                                hover: {
                                    enabled: true
                                }
                            }
                        },
                        lineWidth: 2
                    }
                },
                colors:["rgb(115, 172, 240)","rgb(115, 172, 240)"],
                series: [{
                    name: '写流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            for (i = -9; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    y: Math.random()
                                });
                            }
                            return data;
                        }
                        catch(e){
                            console.log(e);
                        }
                    }())
                },{
                    name: '读流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            for (i = -9; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    y: Math.random()
                                });
                            }
                            return data;
                        }
                        catch(e){
                            console.log(e);
                        }
                    }())
                }]
            });
            $('#vol_write').click(function () {
                var series1 = chart.series[0];
                var series2 = chart.series[1];
                series1.show();
                series2.hide();
            });
            $('#vol_read').click(function () {
                var series1 = chart.series[0];
                var series2 = chart.series[1];
                series1.hide();
                series2.show();
            });
        }`);
    
class CentralStoreViewPage extends Page
    constructor: (@sd, @switch_to_page) ->
        super "centralviewpage-", "html/centralstoreviewpage.html"
        @vm.show_cam = false
        $(@sd.stats).on "updated", (e, source) =>
            if @has_rendered
                latest = source.items[source.items.length-1]
                @vm.cpu_load  = parseInt latest.store_cpu
                @vm.cache_load  = parseInt latest.store_cache
                @vm.mem_load = parseInt latest.store_mem
                @vm.system = parseInt latest.store_system
                @vm.temp = parseInt latest.temp
                @vm.cap = parseInt latest.store_cap
                @refresh_pie parseInt(latest.store_cap), parseInt(latest.store_cap_total), parseInt(latest.store_cap_remain)
                @vm.cap_num = (latest.store_cap_total/1024).toFixed(2)
                @refresh_store_num()
                
                #@sparkline_stats(@vm.system,@vm.temp,@vm.cap)
                #@get_cap(latest)
                #@vm.on_monitor = @_ping()
                #@refresh_num()
                #@waterbubble(latest.store_system,latest.temp,latest.store_cap)
                #@gauge_system(latest.store_system)
        $(@sd.journals).on "updated", (e, source) =>
            @vm.journal = @subitems()
           
        $(@sd.centers).on "updated", (e, source) =>
            num = []
            ((num.push i) for i in source.items when i.Devtype is "storage" and i.Status)
            @vm.on_monitor = num.length
        
        $(@sd.stores).on "updated", (e, source) =>
            @vm.warning_number = source.items.NumOfJours
            @vm.disk_number = source.items.NumOfDisks
            @vm.raid_number = source.items.NumOfRaids
            @vm.volume_number = source.items.NumOfVols
            
        $(@sd.centers).on "updated", (e, source) =>
            tmp = []
            for i in source.items
                if i.Devtype is "storage"
                    tmp.push i
            @vm.process_num = tmp.length
            
    define_vm: (vm) =>
        vm.lang = lang.central_store_view
        vm.cpu_load = 0
        vm.cache_load = 0
        vm.mem_load = 0
        vm.system = 0
        vm.temp = 0
        vm.cap = 0
        vm.cap_load = 30
        vm.cap_load_availed = 70
        vm.status_server = "normal"
        vm.change_status = @change_status
        vm.cap_num = 0
        vm.machine_num = 0
        vm.warning_num = 0
        vm.process_num = 0
        vm.connect_number = 0
        vm.break_number = 0
        vm.raid_number = 0
        vm.volume_number = 0
        vm.disk_number = 0
        vm.clear_log = @clear_log
        vm.journals = []
        vm.flow_type = "fwrite_mb"
        vm.rendered = @rendered
        vm.fattr_journal_status = fattr.journal_status
        vm.fattr_detail_store = fattr.detail_store
        vm.fattr_view_status = fattr.view_status
        vm.switch_to_page = @switch_to_page 
        vm.$watch "cpu_load", (nval, oval) =>
            $("#cpu-load").data("easyPieChart").update?(nval) if @has_rendered
            return
        vm.$watch "cache_load", (nval, oval) =>
            $("#cache-load").data("easyPieChart").update?(nval) if @has_rendered
            return
        vm.$watch "mem_load", (nval, oval) =>
            $("#mem-load").data("easyPieChart").update?(nval) if @has_rendered
            return
        vm.journal = @subitems()
        vm.journal_info = @subitems_info()
        vm.journal_warning = @subitems_warning()
        vm.journal_critical = @subitems_critical()
        vm.journal_unhandled = @subitems_unhandled()
        
        vm.detail_cpu = @detail_cpu
        vm.detail_cache = @detail_cache
        vm.detail_mem = @detail_mem

        vm.detail_break = @detail_break
        vm.detail_disk = @detail_disk   
        vm.detail_raid = @detail_raid
        vm.detail_volume = @detail_volume
        
        vm.switch_net_write = @switch_net_write
        vm.switch_net_read = @switch_net_read
        vm.switch_vol_write = @switch_vol_write
        vm.switch_vol_read = @switch_vol_read
        vm.net_write = @net_write
        vm.net_read = @net_read
        vm.on_monitor = 0
        vm.all_checked = false
        vm.$watch "all_checked", =>
            for r in vm.journal_unhandled
                r.checked = vm.all_checked
        vm.handle_log = @handle_log
        vm.show_cam = false
        vm.alarm = @alarm()
        
    rendered: () =>
        super()
        $('.tooltips').tooltip()
        @vm.journal = @subitems()
        @vm.journal_info = @subitems_info()
        @vm.journal_warning = @subitems_warning()
        @vm.journal_critical = @subitems_critical()
        @vm.journal_unhandled = @subitems_unhandled()
        @update_circle()
        
        @data_table1 = $("#log-table1").dataTable dtable_opt(retrieve: true, bSort: false,scrollX: true)
        @data_table2 = $("#log-table2").dataTable dtable_opt(retrieve: true, bSort: false,scrollX: true)
        @data_table3 = $("#log-table3").dataTable dtable_opt(retrieve: true, bSort: false,scrollX: true)
        @data_table4= $("#log-table4").dataTable dtable_opt(retrieve: true, bSort: false,scrollX: true)

        $(".dataTables_filter input").addClass "m-wrap small"
        $(".dataTables_length select").addClass "m-wrap small"
        #$(".dataTables_filter input[type=search]").css({"background-color":"yellow","font-size":"200%"})
        $scroller1 = $("#journals-scroller-1")
        $scroller2 = $("#journals-scroller-2")
        $scroller3 = $("#journals-scroller-3")
        $scroller4 = $("#journals-scroller-4")
        $scroller1.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller1.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
        $scroller2.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller2.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
        $scroller3.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller3.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
        $scroller4.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller4.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
        $('.countup').counterUp({delay: 2,time: 1000})
        
        try
            @plot_flow_in @sd.stats.items
            @plot_flow_out @sd.stats.items
            @pie_system @sd.stats.items
            @pie_temp @sd.stats.items
            @pie_cap @sd.stats.items
            @column_chart @sd.stats.items
            @plot_pie 0,0,0 
            @refresh_num()
            @refresh_store_num()
            @vm.alarm = @alarm()
        catch e
            console.log e
        #@column_chart([])
        #@flot_system @sd.stats.items
        #@flot_temp @sd.stats.items
        #@flot_cap @sd.stats.items
        #@waterbubble 0,0,0
        #@gauge_system @sd.stats.items
        #@sparkline_stats 0,0,0
        
        #@webcam() 
    subitems: () =>
        try
            #arrays = subitems @sd.journals.items, Uid:"", Message:"", Chinese_message:"", Level:"", Created_at:"", Updated_at:""
            arrays = []
            for i in @sd.journals.items
                i.created = i.created.replace("-","/").replace("-","/").replace("T","-").replace("+08:00","")
                if i.status
                    i.chinese_status = "已处理"
                else
                    i.chinese_status = "未处理"
                arrays.push i
            arrays.reverse()
        catch error
            return []
        ###arrays = [{"date":"2016/09/07 08:45:37","level":"info","chinese_message":"阵列 RAID 已创建"},\
                  {"date":"2016/09/07 08:45:37","level":"critical","chinese_message":"阵列 RAID 已创建"},\
                  {"date":"2016/09/07 08:45:37","level":"critical","chinese_message":"阵列 RAID 已创建"},\
                  {"date":"2016/09/07 08:45:37","level":"warning","chinese_message":"阵列 RAID 已创建"},\
                  {"date":"2016/09/07 08:45:37","level":"info","chinese_message":"阵列 RAID 已创建"},\
                  {"date":"2016/09/07 08:45:37","level":"info","chinese_message":"阵列 RAID 已创建"},\
                  {"date":"2016/09/07 08:45:37","level":"info","chinese_message":"阵列 RAID 已创建"},\
                  {"date":"2016/09/07 08:45:37","level":"warning","chinese_message":"阵列 RAID 已创建"},\
                  {"date":"2016/09/07 08:45:37","level":"info","chinese_message":"阵列 RAID 已创建"},\
                  {"date":"2016/09/07 08:45:37","level":"warning","chinese_message":"阵列 RAID 已创建"}]###
    subitems_info: () =>
        info = []
        ((info.push i) for i in @subitems() when i.level is 'info')
        info
             
    subitems_warning: () =>
        info = []
        ((info.push i) for i in @subitems() when i.level is 'warning')
        info
            
    subitems_critical: () =>
        info = []
        ((info.push i) for i in @subitems() when i.level is 'critical')
        info
        
    subitems_unhandled: () =>
        info = []
        for i in @subitems() 
            if !i.status
                i.chinese_status = "未处理"
                i.checked = false
                info.push i
        info
        
    alarm: () =>
        return @sd.warnings.items
        
    handle_log: () =>
        (new CentralHandleLogModal(@sd, this)).attach()
        
    webcam: () =>
        $(`function() {
              var sayCheese = new SayCheese('#webcam', { audio: false });
              sayCheese.on('start', function() {
                this.takeSnapshot();
              });
            
              sayCheese.on('snapshot', function(snapshot) {
                try{
                    var canvas = document.getElementById('canvas'); 
                    var context = canvas.getContext('2d');
                    context.drawImage(snapshot, 0, 0, 320, 240);
                    console.log(snapshot);
                }
                catch(e){
                    console.log(e);
                }
              });
            
              sayCheese.start();
              
              $('#shot').click(function () {
                console.log(sayCheese);
                sayCheese.takeSnapshot();
              });
        }`)
            
    _ping: () =>
        num = []
        ((num.push i) for i in @sd.centers.items when i.Devtype is "storage" and i.Status)
        num.length
        
    gauge_system:(system) =>
        console.log system
        $(`function () {
            var gaugeOptions = {
                chart: {
                    type: 'solidgauge'
                },
                title: {
                    text:"",
                    style:{
                        fontWeight:'bold',
                        fontSize:19,
                        color:'#000'
                    }
                },
                pane: {
                    center: ['50%', '85%'],
                    size: '140%',
                    startAngle: -90,
                    endAngle: 90,
                    background: {
                        backgroundColor: (Highcharts.theme && Highcharts.theme.background2) || '#EEE',
                        innerRadius: '60%',
                        outerRadius: '100%',
                        shape: 'arc'
                    }
                },
                tooltip: {
                    enabled: false
                },
                exporting: {
                    enabled: false
                },
                credits: {
                    enabled:false
                },
                // the value axis
                yAxis: {
                    stops: [
                        [0.1, '#55BF3B'], // green
                        [0.5, '#DDDF0D'], // yellow
                        [0.9, '#DF5353'] // red
                    ],
                    lineWidth: 0,
                    minorTickInterval: null,
                    tickPixelInterval: 400,
                    tickWidth: 0,
                    title: {
                        y: -70
                    },
                    labels: {
                        y: 16
                    }
                },
                plotOptions: {
                    solidgauge: {
                        dataLabels: {
                            y: 5,
                            borderWidth: 0,
                            useHTML: true
                        }
                    }
                }
            };
            // The speed gauge
            $('#sparkline_bar1').highcharts(Highcharts.merge(gaugeOptions, {
                yAxis: {
                    min: 0,
                    max: 100,
                    title: {
                        text: ''
                    }
                },
                credits: {
                    enabled: false
                },
                series: [{
                    name: 'Speed',
                    data: [80],
                    dataLabels: {
                        format: '<div style="text-align:center"><span style="font-size:25px;color:' +
                        ((Highcharts.theme && Highcharts.theme.contrastTextColor) || 'black') + '">{y}</span><br/>' +
                        '<span style="font-size:12px;color:silver">%</span></div>'
                    },
                    tooltip: {
                        valueSuffix: '%'
                    }
                }]
            }));
            setInterval(function () {
                // Speed
                try{
                    var chart = $('#sparkline_bar1').highcharts(),
                        point,
                        newVal,
                        inc;
                    if (chart) {
                        point = chart.series[0].points[0];
                        //inc = Math.round((Math.random() - 0.5) * 100);
                        //newVal = point.y + inc;
                        //if (newVal < 0 || newVal > 200) {
                        //    newVal = point.y - inc;
                        //}
                        newVal = system[system.length - 1]['store_system']
                        point.update(newVal);
                    }
                }
                catch(e){
                    console.log(e);
                }
            }, 2000);
        }`)
        
    waterbubble: (system,temp,cap) =>
        opts1 = {
                lines: 12, # // The number of lines to draw
                angle: 0, # // The length of each line
                lineWidth: 0.35, # // The line thickness
                #fontSize: 140,
                pointer: {
                  length: 0.76,
                  strokeWidth: 0.034,
                  color: '#000000'
                },
                limitMax: 'false',   # // If true, the pointer will not go past the end of the gauge
                colorStart: 'rgb(87, 199, 212)',   # // Colors
                colorStop: 'rgb(87, 199, 212)',    # // just experiment with them
                strokeColor: '#E0E0E0',   # // to see which ones work best for you
                generateGradient: true
                };
                
        opts2 = {
                lines: 12, # // The number of lines to draw
                angle: 0, # // The length of each line
                lineWidth: 0.35, # // The line thickness
                #fontSize: 140,
                pointer: {
                  length: 0.76,
                  strokeWidth: 0.034,
                  color: '#000000'
                },
                limitMax: 'false',   # // If true, the pointer will not go past the end of the gauge
                colorStart: 'rgb(98, 168, 234)',   # // Colors
                colorStop: 'rgb(98, 168, 234)',    # // just experiment with them
                strokeColor: '#E0E0E0',   # // to see which ones work best for you
                generateGradient: true
                };
        opts3 = {
                lines: 12, # // The number of lines to draw
                angle: 0, # // The length of each line
                lineWidth: 0.35, # // The line thickness
                #fontSize: 140,
                pointer: {
                  length: 0.76,
                  strokeWidth: 0.034,
                  color: '#000000'
                },
                limitMax: 'false',   # // If true, the pointer will not go past the end of the gauge
                colorStart: 'rgb(146, 109, 222)',   # // Colors
                colorStop: 'rgb(146, 109, 222)',    # // just experiment with them
                strokeColor: '#E0E0E0',   # // to see which ones work best for you
                generateGradient: true
                };
        target1 = document.getElementById('sparkline_bar1'); # // your canvas element
        target2 = document.getElementById('sparkline_bar2'); # // your canvas element
        target3 = document.getElementById('sparkline_bar3'); # // your canvas element
        gauge1 = new Gauge(target1).setOptions(opts1); # // create sexy gauge!
        gauge2 = new Gauge(target2).setOptions(opts2); # // create sexy gauge!
        gauge3 = new Gauge(target3).setOptions(opts3); # // create sexy gauge!
                
        gauge1.maxValue = 100; # // set max gauge value
        gauge1.animationSpeed = 65; # // set animation speed (32 is default value)
        gauge1.set(system); # // set actual value
        gauge1.setTextField(document.getElementById("gauge-text1"));
        gauge2.setTextField(document.getElementById("gauge-text2"));
        gauge3.setTextField(document.getElementById("gauge-text3"));
        
        gauge2.maxValue = 100; # // set max gauge value
        gauge2.animationSpeed = 65; # // set animation speed (32 is default value)
        gauge2.set(temp); # // set actual value
                
        gauge3.maxValue = 100; # // set max gauge value
        gauge3.animationSpeed = 65; # // set animation speed (32 is default value)
        gauge3.set(cap); # // set actual value
       
    refresh_store_num: () =>
        if @sd.stores.items isnt null
            @vm.raid_number = parseInt @sd.stores.items.NumOfRaids
            @vm.volume_number = parseInt @sd.stores.items.NumOfVols
            @vm.disk_number = parseInt @sd.stores.items.NumOfDisks
        else
            @vm.raid_number = 0
            @vm.volume_number = 0
            @vm.disk_number = 0

    get_cap: (latest) =>
        datas_total = []
        try
            for i in latest.storages
                if i.info[0].df.length = 2
                    datas_total.push {name:i.ip,y:i.info[0].df[1].total}
        catch e
            console.log e
   
        ###for i in @sd.stores.items.Disk
            if i.MachineId not in machine_total
                machine_total.push i.MachineId
                
        for i in @sd.stores.items.Disk
            data_total[i.MachineId] = 0
           
        for i in @sd.stores.items.Disk
            data_total[i.MachineId] = data_total[i.MachineId] + i.CapSector/2/1024/1024
            
        for i in machine_total
            datas_total.push {name:i,y:data_total[i]}
            
        for i in datas_total
            for j in @sd.centers.items
                if i['name'] is j.Uuid
                    i['name'] = j.Ip ###
        datas_total
        
    column_chart:(items) =>
        $(`function () {
            $(document).ready(function () {
                Highcharts.setOptions({
                    global: {
                        useUTC: false
                    }
                });
                $('#column_chart').highcharts({
                    chart: {
                      type: 'column',
                      options3d: {
                        enabled: true,
                        alpha: 10,
                        beta: 20,
                        depth: 170
                      },
                      events: {
                        load: function () {
                            var series1 = this.series[0];
                            setInterval(function () {
                                datas_total = [];
                                try{
                                    for (var i=0;i< items[items.length - 1].storages.length;i++){
                                        if( items[items.length - 1].storages[i].info[0].df.length == 2){
                                            datas_total.push({name: items[items.length - 1].storages[i].ip,y: items[items.length - 1].storages[i].info[0].df[1].total});
                                        }
                                    };
                                    if (datas_total.length == 0){
                                        datas_total = [{name:"随机数据",y:100},{name:"随机数据",y:200},{name:"随机数据",y:300},{name:"随机数据",y:200},{name:"随机数据",y:100},{name:"随机数据",y:50}]
                                    }
                                    series1.setData(datas_total);
                                }
                                catch(e){
                                    console.log(e);
                                }
                            }, 3000);
                        }
                      }
                    },
                    title: {
                      text: ''
                    },
                    subtitle: {
                      text: ''
                    },
                    credits: {
                      enabled: false
                    },
                    exporting: {
                      enabled: false
                    },
                    legend: {
                      enabled: true,
                      backgroundColor: '#FFFFFF',
                      floating: true,
                      align: 'right',
                      layout: 'vertical',
                      verticalAlign: 'top',
                      itemStyle: {
                        color: 'rgb(110,110,110)',
                        fontWeight: '100',
                        fontFamily: "Microsoft YaHei"
                      }
                    },
                    xAxis: {
                      crosshair: true,
                      tickWidth: 0,
                      labels: {
                        enabled: false
                      }
                    },
                    yAxis: {
                      min: 0,
                      title: {
                        text: 'GB'
                      }
                    },
                    tooltip: {
                      headerFormat: '<span style="font-size:10px">{point.key}</span><table>',
                      pointFormat: '<tr><td style="color:{series.color};padding:0"></td>' + '<td style="padding:0"><b>{point.y:.1f}GB </b></td></tr>',
                      footerFormat: '</table>',
                      shared: true,
                      useHTML: true,
                      style: {
                        color: '#fff',
                        fontSize: '12px',
                        opacity: 0.8
                      },
                      borderRadius: 0,
                      borderColor: '#000',
                      backgroundColor: '#000'
                    },
                    plotOptions: {
                      column: {
                        animation: false,
                        pointPadding: 0.2,
                        borderWidth: 0,
                        color: 'rgba(60, 192, 150,0.2)',
                        borderColor: 'rgb(60, 192, 150)',
                        borderWidth: 1,
                        pointPadding: 0,
                        events: {
                          legendItemClick: function() {
                            return false;
                          },
                          click: function(event) {}
                        }
                      }
                    },
                    series: [
                      {
                        name: '总容量',
                        data: [{name:"随机数据",y:100},{name:"随机数据",y:200},{name:"随机数据",y:300},{name:"随机数据",y:200},{name:"随机数据",y:100},{name:"随机数据",y:50}]
                      }
                    ]
                });
            });
        }`)
        
    pie_system: (items) =>
        $(`function () {
            $(document).ready(function () {
                Highcharts.setOptions({
                    global: {
                        useUTC: false
                    }
                });
                $('#sparkline_bar1').highcharts({
                    chart: {
                      type: 'pie',
                      margin: [0, 0, 25, 0],
                      events: {
                            load: function () {
                                var series1 = this.series[0];
                                setInterval(function () {
                                    try{
                                        var type = "store_system"
                                        var y = items[items.length - 1][type];
                                        series1.setData([['已用',y], ['剩余',100 - y]]);
                                    }
                                    catch(e){
                                        console.log(e);
                                    }
                                }, 3000);
                            }
                        }
                    },
                    title: {
                      text: '系统空间',
                      verticalAlign: "bottom",
                      style: {
                        color: '#000',
                        fontFamily: 'Microsoft YaHei',
                        fontSize: 16
                      }
                    },
                    subtitle: {
                      text: ''
                    },
                    xAxis: {
                      type: 'category',
                      gridLineColor: '#FFF',
                      tickColor: '#FFF',
                      labels: {
                        enabled: false,
                        rotation: -45,
                        style: {
                          fontSize: '13px',
                          fontFamily: 'opensans-serif'
                        }
                      }
                    },
                    yAxis: {
                      gridLineColor: '#FFF',
                      min: 0,
                      max: 100,
                      title: {
                        text: ''
                      },
                      labels: {
                        enabled: true
                      }
                    },
                    credits: {
                      enabled: false
                    },
                    exporting: {
                      enabled: false
                    },
                    legend: {
                      enabled: true,
                      backgroundColor: '#FFFFFF',
                      floating: true,
                      align: 'right',
                      layout: 'vertical',
                      verticalAlign: 'top',
                      itemStyle: {
                        color: 'rgb(110,110,110)',
                        fontWeight: '100',
                        fontFamily: "Microsoft YaHei"
                      }
                    },
                    tooltip: {
                      pointFormat: '<b>{point.y:.1f}%</b>',
                      style: {
                        color: '#fff',
                        fontSize: '12px',
                        opacity: 0.8
                      },
                      borderRadius: 0,
                      borderColor: '#000',
                      backgroundColor: '#000'
                    },
                    plotOptions: {
                      pie: {
                        animation: false,
                        shadow: false,
                        borderColor: "rgba(0,0,0,0)",
                        dataLabels: {
                          enabled: false
                        }
                      }
                    },
                    colors: ["rgb(87, 199, 212)", "rgba(87, 199, 212,0.2)"],
                    series: [{
                        name: '系统空间',
                        data: [
                            ['已用',   0],
                            ['剩余',   100]
                        ]
                    }]
                });
            });
        }`);
        
    pie_temp: (items) =>
        $(`function () {
            $(document).ready(function () {
                Highcharts.setOptions({
                    global: {
                        useUTC: false
                    }
                });
                $('#sparkline_bar2').highcharts({
                    chart: {
                      type: 'pie',
                      margin: [0, 0, 25, 0],
                      events: {
                            load: function () {
                                var series1 = this.series[0];
                                setInterval(function () {
                                    try{
                                        var type = "temp"
                                        var y = items[items.length - 1][type];
                                        series1.setData([['已用',y], ['剩余',100 - y]]);
                                    }
                                    catch(e){
                                        console.log(e);
                                    }
                                }, 3000);
                            }
                        }
                    },
                    title: {
                      text: '温度',
                      verticalAlign: "bottom",
                      style: {
                        color: '#000',
                        fontFamily: 'Microsoft YaHei',
                        fontSize: 16
                      }
                    },
                    subtitle: {
                      text: ''
                    },
                    xAxis: {
                      type: 'category',
                      gridLineColor: '#FFF',
                      tickColor: '#FFF',
                      labels: {
                        enabled: false,
                        rotation: -45,
                        style: {
                          fontSize: '13px',
                          fontFamily: 'opensans-serif'
                        }
                      }
                    },
                    yAxis: {
                      gridLineColor: '#FFF',
                      min: 0,
                      max: 100,
                      title: {
                        text: ''
                      },
                      labels: {
                        enabled: true
                      }
                    },
                    credits: {
                      enabled: false
                    },
                    exporting: {
                      enabled: false
                    },
                    legend: {
                      enabled: true,
                      backgroundColor: '#FFFFFF',
                      floating: true,
                      align: 'right',
                      layout: 'vertical',
                      verticalAlign: 'top',
                      itemStyle: {
                        color: 'rgb(110,110,110)',
                        fontWeight: '100',
                        fontFamily: "Microsoft YaHei"
                      }
                    },
                    tooltip: {
                      pointFormat: '<b>{point.y:.1f}%</b>',
                      style: {
                        color: '#fff',
                        fontSize: '12px',
                        opacity: 0.8
                      },
                      borderRadius: 0,
                      borderColor: '#000',
                      backgroundColor: '#000'
                    },
                    plotOptions: {
                      pie: {
                        animation: false,
                        shadow: false,
                        borderColor: "rgba(0,0,0,0)",
                        dataLabels: {
                          enabled: false
                        }
                      }
                    },
                    colors: ["rgb(98, 168, 234)", "rgba(98, 168, 234,0.2)"],
                    series: [{
                        name: '温度',
                        data: [
                            ['已用',   0],
                            ['剩余',   100]
                        ]
                    }]
                });
            });
        }`);
        
    pie_cap: (items) =>
        $(`function () {
            $(document).ready(function () {
                Highcharts.setOptions({
                    global: {
                        useUTC: false
                    }
                });
                $('#sparkline_bar3').highcharts({
                    chart: {
                      type: 'pie',
                      margin: [0, 0, 25, 0],
                      events: {
                            load: function () {
                                var series1 = this.series[0];
                                setInterval(function () {
                                    try{
                                        var type = "store_cap"
                                        var y = items[items.length - 1][type];
                                        series1.setData([['已用',y], ['剩余',100 - y]]);
                                    }
                                    catch(e){
                                        console.log(e);
                                    }
                                }, 3000);
                            }
                        }
                    },
                    title: {
                      text: '存储空间',
                      verticalAlign: "bottom",
                      style: {
                        color: '#000',
                        fontFamily: 'Microsoft YaHei',
                        fontSize: 16
                      }
                    },
                    subtitle: {
                      text: ''
                    },
                    xAxis: {
                      type: 'category',
                      gridLineColor: '#FFF',
                      tickColor: '#FFF',
                      labels: {
                        enabled: false,
                        rotation: -45,
                        style: {
                          fontSize: '13px',
                          fontFamily: 'opensans-serif'
                        }
                      }
                    },
                    yAxis: {
                      gridLineColor: '#FFF',
                      min: 0,
                      max: 100,
                      title: {
                        text: ''
                      },
                      labels: {
                        enabled: true
                      }
                    },
                    credits: {
                      enabled: false
                    },
                    exporting: {
                      enabled: false
                    },
                    legend: {
                      enabled: true,
                      backgroundColor: '#FFFFFF',
                      floating: true,
                      align: 'right',
                      layout: 'vertical',
                      verticalAlign: 'top',
                      itemStyle: {
                        color: 'rgb(110,110,110)',
                        fontWeight: '100',
                        fontFamily: "Microsoft YaHei"
                      }
                    },
                    tooltip: {
                      pointFormat: '<b>{point.y:.1f}%</b>',
                      style: {
                        color: '#fff',
                        fontSize: '12px',
                        opacity: 0.8
                      },
                      borderRadius: 0,
                      borderColor: '#000',
                      backgroundColor: '#000'
                    },
                    plotOptions: {
                      pie: {
                        animation: false,
                        shadow: false,
                        borderColor: "rgba(0,0,0,0)",
                        dataLabels: {
                          enabled: false
                        }
                      }
                    },
                    colors: ["rgb(146, 109, 222)", "rgba(146, 109, 222,0.2)"],
                    series: [{
                        name: '存储空间',
                        data: [
                            ['已用',   0],
                            ['剩余',   100]
                        ]
                    }]
                });
            });
        }`);
        
    refresh_num: () =>
        #@vm.cap_num = @_cap()
        @vm.machine_num = @_machine()
        @vm.warning_num = @_warning()
        @vm.process_num = @_process()
        
    _cap: () =>
        cap = 0
        try
            cap = @sd.stats.items[@sd.stats.items.length-1].store_cap_total/1024
        catch e
            console.log e
        cap.toFixed(2)
        
    _machine: () =>
        option = []
        ((option.push i.cid) for i in @sd.clouds.items when i.devtype is "storage")
        option.length
        
    _warning: () =>
        arrays = []
        for i in @sd.journals.items
            if i.level is "warning" or i.level is "critical"
                if !i.status
                    arrays.push i
        arrays.length
        
    _process: () =>
        if @sd.centers.items != null
            tmp = []
            items = subitems @sd.centers.items, Uuid:"", Ip:"", Slotnr:"", Created: "",Devtype:""
            ((tmp.push i) for i in items when i.Devtype is "storage")
            tmp.length
        
    update_circle: () =>
        opt1 = animate: 1000, size: 115, lineWidth: 5, lineCap: "butt", barColor: "rgb(255, 184, 72)",trackColor: 'rgba(255, 184, 72,0.1)',scaleColor: false
        opt2 = animate: 1000, size: 115, lineWidth: 5, lineCap: "butt", barColor: "rgb(40, 183, 121)",trackColor: 'rgba(40, 183, 121,0.1)',scaleColor: false
        opt3 = animate: 1000, size: 115, lineWidth: 5, lineCap: "butt", barColor: "rgb(52, 152, 219)",trackColor: 'rgba(52, 152, 219,0.1)',scaleColor: false
        try
            $("#cpu-load").easyPieChart opt1
            $("#cpu-load").data("easyPieChart").update? @vm.cpu_load
            $("#cache-load").easyPieChart opt2
            $("#cache-load").data("easyPieChart").update? @vm.cache_load
            $("#mem-load").easyPieChart opt3
            $("#mem-load").data("easyPieChart").update? @vm.mem_load
        catch e
            console.log e
            
    change_status: (type) =>
        @vm.status_server = type
        
    clear_log:() =>
        if @vm.journal.length is 0
            (new MessageModal @vm.lang.clear_log_error).attach()
            return
        (new ConfirmModal(@vm.lang.clear_log_tips, =>
            @frozen()
            chain = new Chain()
            chain.chain(=> (new JournalRest(@sd.host)).delete_log())
            chain.chain @sd.update("all")
            show_chain_progress(chain).done =>
                @attach()
                (new MessageModal @vm.lang.clear_log_success).attach()
        )).attach()

    detail_break: () =>
        return
        ip = '192.168.2.103'
        @frozen()
        detail = (new JournalRest(@sd.host)).disk_info(ip)
        detail.done (data) =>
            (new CentralStoreBreakModal(@sd, this, data.detail)).attach()
        return
    detail_disk: () =>
        return
        ip = '192.168.2.103'
        @frozen()
        detail = (new JournalRest(@sd.host)).disk_info(ip)
        detail.done (data) =>
            console.log data
            try
                (new CentralStoreDiskModal(@sd, this, data.detail.D)).attach()
            catch error
                console.log error
        return
    detail_raid: () => 
        return
        ip = '192.168.2.103'
        @frozen()
        detail = (new JournalRest(@sd.host)).disk_info(ip)
        detail.done (data) =>
            console.log data
            try
                (new CentralStoreRaidModal(@sd, this, data.detail.R)).attach()
            catch error
                console.log error
        return
    detail_volume: () =>
        return
        ip = '192.168.2.103'
        @frozen()
        detail = (new JournalRest(@sd.host)).disk_info(ip)
        detail.done (data) =>
            (new CentralStoreVolumeModal(@sd, this, data.detail.V)).attach()
        return
        
    detail_cpu: () =>
        (new CentralServerCpuModal(@sd, this)).attach()
    
    detail_cache: () =>
        return
        (new CentralServerCacheModal(@sd, this)).attach()
        
    detail_mem: () =>
        (new CentralServerMemModal(@sd, this)).attach()
        
    add_time_to_journal:(items) =>
        journals = []
        change_time = `function funConvertUTCToNormalDateTime(utc)
        {
            var date = new Date(utc);
            var ndt;
            ndt = date.getFullYear()+"/"+(date.getMonth()+1)+"/"+date.getDate()+"-"+date.getHours()+":"+date.getMinutes()+":"+date.getSeconds();
            return ndt;
        }`
        for item in items
            item.date = change_time(item.created_at*1000)
            journals.push item
        
        return journals
    
    flot_cap: (yaxis) =>
        $(document).ready(`function () {
            Highcharts.setOptions({
                global: {
                    useUTC: false
                }
            });
            var chart = Highcharts.chart('sparkline_bar3', {
                chart: {
                    type: 'area',
                    //animation:false,
                    //margin:[0,0,0,0],
                    backgroundColor: 'rgba(0,0,0,0)',
                    animation: Highcharts.svg, // don't animate in old IE
                    marginRight: 10,
                    //plotBorderColor:"rgb(235, 235, 235)",
                    //plotBorderWidth:1,
                    //backgroundColor:"rgb(250, 250, 250)",
                    events: {
                        load: function () {
                            var series1 = this.series[0];
                            setInterval(function () {
                                try{
                                    var type1 = 'store_cap';
                                    var x = (new Date()).getTime(), // current time
                                        y1 = yaxis[yaxis.length - 1][type1];
                                        y2 = Math.random()
                                    series1.addPoint([x, y1+y2], true, true);
                                }
                                catch(e){
                                    console.log(e);
                                }
                            }, 3000);
                        }
                    }
                },
                title: {
                    text: ''
                },
                xAxis: {
                    tickWidth: 0,
                    lineWidth: 0,
                    labels: {
                        enabled: false
                    },
                    type: 'datetime',
                    tickPixelInterval: 150
                },
                yAxis: {
                    //labels:{
                    //    enabled:false
                    //},
                    gridLineWidth:0,
                    min:-1,
                    //max:150,
                    title: {
                        text: ''
                    },
                    plotLines: [{
                        value: 0,
                        width: 0,
                        color: '#808080'
                    }]
                },
                tooltip: {
                    formatter: function () {
                        return Highcharts.numberFormat(this.y, 2);
                    },
                    style: {
                        color:'#fff',
                        fontSize:'12px',
                        opacity:0.8
                    },
                    borderRadius:0,
                    borderColor:'#000',
                    backgroundColor:'#000',
                },
                credits: {
                    enabled:false
                },
                legend: {
                    enabled: false
                },
                exporting: {
                    enabled: false
                },
                //colors:["#62a8ea","#a58add"],
                plotOptions: {
                    area: {
                        lineColor: "rgb(87, 199, 212)",
                        lineWidth:1,
                        fillColor: "rgba(87, 199, 212,0.1)",
                        threshold: null,
                        animation:false,
                        states: {
                            hover: {
                                lineWidth: 1
                            }
                        },
                        marker: {
                            enabled: false,
                            symbol: 'circle',
                            radius: 1,
                            lineWidth:1,
                            lineColor:"#fff",
                            fillColor:"rgba(165, 138, 221,0.6)"
                        },
                        fillOpacity:0.3
                    }
                },
                series: [{
                    name: '写流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            for (i = -9; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    y: Math.random()
                                });
                            }
                            return data;
                        }
                        catch(e){
                            console.log(e);
                        }
                    }())
                }]
            });
        }`);
        
    flot_system: (yaxis) =>
        $(document).ready(`function () {
            Highcharts.setOptions({
                global: {
                    useUTC: false
                }
            });
            var chart = Highcharts.chart('sparkline_bar1', {
                chart: {
                    type: 'area',
                    //animation:false,
                    //margin:[0,0,0,0],
                    backgroundColor: 'rgba(0,0,0,0)',
                    animation: Highcharts.svg, // don't animate in old IE
                    marginRight: 10,
                    //plotBorderColor:"rgb(235, 235, 235)",
                    //plotBorderWidth:1,
                    //backgroundColor:"rgb(250, 250, 250)",
                    events: {
                        load: function () {
                            var series1 = this.series[0];
                            setInterval(function () {
                                try{
                                    var type1 = 'store_system';
                                    var x = (new Date()).getTime(), // current time
                                        y1 = yaxis[yaxis.length - 1][type1];
                                        y2 = Math.random()
                                    series1.addPoint([x, y1+y2], true, true);
                                }
                                catch(e){
                                    console.log(e);
                                }
                            }, 3000);
                        }
                    }
                },
                title: {
                    text: ''
                },
                xAxis: {
                    tickWidth: 0,
                    lineWidth: 0,
                    labels: {
                        enabled: false
                    },
                    type: 'datetime',
                    tickPixelInterval: 150
                },
                yAxis: {
                    //labels:{
                    //    enabled:false
                    //},
                    gridLineWidth:0,
                    min:-1,
                    //max:150,
                    title: {
                        text: ''
                    },
                    plotLines: [{
                        value: 0,
                        width: 0,
                        color: '#808080'
                    }]
                },
                tooltip: {
                    formatter: function () {
                        return Highcharts.numberFormat(this.y, 2);
                    },
                    style: {
                        color:'#fff',
                        fontSize:'12px',
                        opacity:0.8
                    },
                    borderRadius:0,
                    borderColor:'#000',
                    backgroundColor:'#000',
                },
                credits: {
                    enabled:false
                },
                legend: {
                    enabled: false
                },
                exporting: {
                    enabled: false
                },
                //colors:["#62a8ea","#a58add"],
                plotOptions: {
                    area: {
                        lineColor: "rgb(98, 168, 234)",
                        lineWidth:1,
                        fillColor: "rgba(98, 168, 234,0.1)",
                        threshold: null,
                        animation:false,
                        states: {
                            hover: {
                                lineWidth: 1
                            }
                        },
                        marker: {
                            enabled: false,
                            symbol: 'circle',
                            radius: 1,
                            lineWidth:1,
                            lineColor:"#fff",
                            fillColor:"rgba(165, 138, 221,0.6)"
                        },
                        fillOpacity:0.3
                    }
                },
                series: [{
                    name: '写流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            for (i = -9; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    y: Math.random()
                                });
                            }
                            return data;
                        }
                        catch(e){
                            console.log(e);
                        }
                    }())
                }]
            });
        }`);
        
    flot_temp: (yaxis) =>
        $(document).ready(`function () {
            Highcharts.setOptions({
                global: {
                    useUTC: false
                }
            });
            var chart = Highcharts.chart('sparkline_bar2', {
                chart: {
                    type: 'area',
                    //animation:false,
                    //margin:[0,0,0,0],
                    backgroundColor: 'rgba(0,0,0,0)',
                    animation: Highcharts.svg, // don't animate in old IE
                    marginRight: 10,
                    //plotBorderColor:"rgb(235, 235, 235)",
                    //plotBorderWidth:1,
                    //backgroundColor:"rgb(250, 250, 250)",
                    events: {
                        load: function () {
                            var series1 = this.series[0];
                            setInterval(function () {
                                try{
                                    var type1 = 'temp';
                                    var x = (new Date()).getTime(), // current time
                                        y1 = yaxis[yaxis.length - 1][type1];
                                        y2 = Math.random();
                                    series1.addPoint([x, y1+y2], true, true);
                                }
                                catch(e){
                                    console.log(e);
                                }
                            }, 3000);
                        }
                    }
                },
                title: {
                    text: ''
                },
                xAxis: {
                    tickWidth: 0,
                    lineWidth: 0,
                    labels: {
                        enabled: false
                    },
                    type: 'datetime',
                    tickPixelInterval: 150
                },
                yAxis: {
                    labels:{
                        enabled:false
                    },
                    gridLineColor: "#FFF",
                    min:-1,
                    //max:150,
                    title: {
                        text: ''
                    },
                    plotLines: [{
                        value: 0,
                        width: 0,
                        color: '#808080'
                    }]
                },
                tooltip: {
                    formatter: function () {
                        return Highcharts.numberFormat(this.y, 2);
                    },
                    style: {
                        color:'#fff',
                        fontSize:'12px',
                        opacity:0.8
                    },
                    borderRadius:0,
                    borderColor:'#000',
                    backgroundColor:'#000',
                },
                credits: {
                    enabled:false
                },
                legend: {
                    enabled: false
                },
                exporting: {
                    enabled: false
                },
                //colors:["#62a8ea","#a58add"],
                plotOptions: {
                    area: {
                        lineColor: "rgb(146, 109, 222)",
                        lineWidth:1,
                        fillColor: "rgba(146, 109, 222,0.1)",
                        fillOpacity:0.3,
                        threshold: null,
                        animation:false,
                        states: {
                            hover: {
                                lineWidth: 1
                            }
                        },
                        marker: {
                            enabled: false,
                            symbol: 'circle',
                            radius: 1,
                            lineWidth:1,
                            lineColor:"#fff",
                            fillColor:"rgba(255,120,120)"
                        }
                    }
                },
                series: [{
                    name: '写流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            for (i = -9; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    y: Math.random()
                                });
                            }
                            return data;
                        }
                        catch(e){
                            console.log(e);
                        }
                    }())
                }]
            });
        }`);
        
    plot_flow_in: (yaxis) =>
        $(document).ready(`function () {
            Highcharts.setOptions({
                global: {
                    useUTC: false
                }
            });
            var chart = Highcharts.chart('flow_stats_in', {
                chart: {
                    type: 'areaspline',
                    //animation:false,
                    animation: Highcharts.svg, // don't animate in old IE
                    marginRight: 10,
                    plotBorderColor:"rgb(255, 255, 255)",
                    plotBorderWidth:1,
                    //backgroundColor:"rgb(250, 250, 250)",
                    events: {
                        load: function (event) {
                            var series1 = this.series[0];
                            var series2 = this.series[1];
                            setInterval(function () {
                                //var maxs =  event.target.yAxis[0].max * 2;
                                //chart.yAxis[0].setExtremes(maxs);
                                try{
                                    var type1 = 'store_net_write';
                                    var type2 = 'store_net_read';
                                    var random = Math.random();
                                    var x = (new Date()).getTime(), // current time
                                        y1 = yaxis[yaxis.length - 1][type1];
                                        y2 = yaxis[yaxis.length - 1][type2];
                                    series1.addPoint([x, y1 + random], true, true);
                                    series2.addPoint([x, y2 + random], true, true);
                                }
                                catch(e){
                                    console.log(e);
                                }
                            }, 3000);
                            series2.hide();
                        }
                    }
                },
                title: {
                    text: ''
                },
                xAxis: {
                    tickWidth: 0,
                    labels: {
                        enabled: false
                    },
                    type: 'datetime',
                    tickPixelInterval: 150
                },
                yAxis: {
                    maxPadding: 2,
                    tickAmount: 4,
                    //gridLineColor: "#FFF",
                    min:-1,
                    title: {
                        text: ''
                    },
                    plotLines: [{
                        value: 0,
                        width: 1,
                        color: '#808080'
                    }]
                },
                tooltip: {
                    formatter: function () {
                        return '<b>' + this.series.name + '</b><br/>' +
                            Highcharts.dateFormat('%Y-%m-%d %H:%M:%S', this.x) + '<br/>' +
                            Highcharts.numberFormat(this.y, 2);
                    },
                    style: {
                        color:'#fff',
                        fontSize:'12px',
                        opacity:0.8
                    },
                    borderRadius:0,
                    borderColor:'#000',
                    backgroundColor:'#000',
                },
                credits: {
                    enabled:false
                },
                legend: {
                    enabled: false
                },
                exporting: {
                    enabled: false
                },
                //colors:["rgba(227,91,90,0.4)","rgba(227,91,243,0.1)"],
                plotOptions: {
                    areaspline: {
                        threshold: null,
                        animation:false,
                        states: {
                            hover: {
                                lineWidth: 1
                            }
                        },
                        fillOpacity: 0.2,
                        fillColor:"rgba(227,91,90,0.4)",
                        marker: {
                            enabled: false,
                            symbol: 'circle',
                            radius: 4,
                            lineWidth:2,
                            lineColor:"#fff",
                            fillColor:"rgba(255,120,120,0.7)",
                            states: {
                                hover: {
                                    enabled: true,
                                    fillColor:"rgb(227,91,90)"
                                }
                            }
                        },
                        lineWidth: 2,
                        lineColor:"rgba(227,91,90,0.5)"
                    }
                },
                series: [{
                    name: '写流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            for (i = -9; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    y: Math.random()
                                });
                            }
                            return data;
                        }
                        catch(e){
                            console.log(e);
                        }
                    }())
                },{
                    name: '读流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            for (i = -9; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    y: Math.random()
                                });
                            }
                            return data;
                        }
                        catch(e){
                            console.log(e);
                        }
                    }())
                }]
            });
            $('#net_write').click(function () {
                var series1 = chart.series[0];
                var series2 = chart.series[1];
                series1.show();
                series2.hide();
            });
            $('#net_read').click(function () {
                var series1 = chart.series[0];
                var series2 = chart.series[1];
                series1.hide();
                series2.show();
            });
        }`);

    plot_flow_out: (yaxis) =>
        $(document).ready(`function () {
            Highcharts.setOptions({
                global: {
                    useUTC: false
                }
            });
            var chart = Highcharts.chart('flow_stats_out', {
                chart: {
                    type: 'areaspline',
                    //animation:false,
                    animation: Highcharts.svg, // don't animate in old IE
                    marginRight: 10,
                    plotBorderColor:"rgb(255, 255, 255)",
                    plotBorderWidth:1,
                    //backgroundColor:"rgb(250, 250, 250)",
                    events: {
                        load: function () {
                            var series1 = this.series[0];
                            var series2 = this.series[1];
                            setInterval(function () {
                                try{
                                    var type1 = 'store_vol_write';
                                    var type2 = 'store_vol_read';
                                    var random = Math.random();
                                    var x = (new Date()).getTime(), // current time
                                        y1 = yaxis[yaxis.length - 1][type1];
                                        y2 = yaxis[yaxis.length - 1][type2];
                                    series1.addPoint([x, y1 + random], true, true);
                                    series2.addPoint([x, y2 + random], true, true);
                                }
                                catch(e){
                                    console.log(e);
                                }
                            }, 3000);
                            series2.hide();
                        }
                    }
                },
                title: {
                    text: ''
                },
                xAxis: {
                    tickWidth: 0,
                    labels: {
                        enabled: false
                    },
                    type: 'datetime',
                    tickPixelInterval: 150
                },
                yAxis: {
                    maxPadding: 2,
                    tickAmount: 4,
                    //gridLineColor: "#FFF",
                    min:-1,
                    title: {
                        text: ''
                    },
                    plotLines: [{
                        value: 0,
                        width: 1,
                        color: '#808080'
                    }]
                },
                tooltip: {
                    formatter: function () {
                        return '<b>' + this.series.name + '</b><br/>' +
                            Highcharts.dateFormat('%Y-%m-%d %H:%M:%S', this.x) + '<br/>' +
                            Highcharts.numberFormat(this.y, 2);
                    },
                    style: {
                        color:'#fff',
                        fontSize:'12px',
                        opacity:0.8
                    },
                    borderRadius:0,
                    borderColor:'#000',
                    backgroundColor:'#000'
                },
                credits: {
                    enabled:false
                },
                legend: {
                    enabled: false
                },
                exporting: {
                    enabled: false
                },
                plotOptions: {
                    areaspline: {
                        threshold: null,
                        animation:false,
                        states: {
                            hover: {
                                lineWidth: 2
                            }
                        },
                        fillOpacity: 0.2,
                        marker: {
                            enabled: false,
                            symbol: 'circle',
                            radius: 4.5,
                            fillColor:"rgb(143, 208, 253)",
                            states: {
                                hover: {
                                    enabled: true
                                }
                            }
                        },
                        lineWidth: 2
                    }
                },
                colors:["rgb(115, 172, 240)","rgb(115, 172, 240)"],
                series: [{
                    name: '写流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            for (i = -9; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    y: Math.random()
                                });
                            }
                            return data;
                        }
                        catch(e){
                            console.log(e);
                        }
                    }())
                },{
                    name: '读流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            for (i = -9; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    y: Math.random()
                                });
                            }
                            return data;
                        }
                        catch(e){
                            console.log(e);
                        }
                    }())
                }]
            });
            $('#vol_write').click(function () {
                var series1 = chart.series[0];
                var series2 = chart.series[1];
                series1.show();
                series2.hide();
            });
            $('#vol_read').click(function () {
                var series1 = chart.series[0];
                var series2 = chart.series[1];
                series1.hide();
                series2.show();
            });
        }`);
    
    refresh_pie: (per, total, remain) =>
        ###cap = 0
        used_cap = 0
        
        chain = new Chain
        chain.chain @sd.update("stores")
        console.log @sd.stores.items
        for i in @sd.stores.items.Disk
            cap = cap + i.CapSector
            
        for i in @sd.stores.items.Raid
            if i.Health is 'normal' 
                used_cap = used_cap + i.Used

        cap = cap/2/1024/1024
        per = used_cap/cap*100
        
        if @sd.stores.items.Disk.length isnt 0
            @plot_pie per, cap.toFixed(0), used_cap.toFixed(0), @sd, this
        else
            @plot_pie 0, 0, 0, @sd, this###
        @plot_pie per, total, remain
            
    plot_pie: (per, total ,remain) =>
        if remain is null
           remain = 0
        used = total - remain
        Highcharts.setOptions(
            lang:
                contextButtonTitle:"图表导出菜单"
                decimalPoint:"."
                downloadJPEG:"下载JPEG图片"
                downloadPDF:"下载PDF文件"
                downloadPNG:"下载PNG文件"
                downloadSVG:"下载SVG文件"
                printChart:"打印图表")
        
        $('#pie_chart').highcharts(
                chart: 
                    type: 'pie'
                    options3d:
                        enabled: true
                        alpha: 45
                        beta: 0
                    #marginBottom:70
                title: 
                    text: ''
                tooltip: 
                    pointFormat: '<b>{point.percentage:.1f}%</b>'
                    style:
                        color:'#fff'
                        fontSize:'15px'
                        opacity:0.8
                    borderColor:'#000'
                    backgroundColor:'#000'
                    borderRadius:0
                credits: 
                    enabled:false
                exporting: 
                    enabled: false
                plotOptions: 
                    pie:
                        states:
                            hover:
                                brightness: 0.08
                        allowPointSelect: true
                        animation:false
                        cursor: 'pointer'
                        depth: 25
                        slicedOffset: 15
                        showInLegend: true
                        dataLabels: 
                            enabled: false
                            format: '{point.percentage:.1f} %'
                            style: 
                                fontSize:'14px'
                        point:
                            events:
                                legendItemClick: () ->return false
                                click: (event) ->
                                    return
                                    if cap
                                        (new CentralPieModal(sd, page, @name, cap, used_cap)).attach();
                legend: 
                    enabled: true
                    backgroundColor: '#FFFFFF'
                    floating: true
                    align: 'right'
                    layout: 'vertical'
                    verticalAlign: 'top'
                    itemStyle: 
                        color: 'rgb(110,110,110)'
                        fontWeight: '100'
                        fontFamily:"Microsoft YaHei"
                    labelFormatter: () ->
                        if @name is '已用容量'
                            return @name + ':' + used + 'GB'
                        else
                            return @name + ':' + remain + 'GB'
                colors:['rgb(130, 192, 150)', 'rgba(60, 192, 150,0.3)']
                series: [
                    type: 'pie'
                    name: ''
                    data: [
                        ['已用容量', per]
                        ['剩余容量', 100-per]
                    ]
                ])
                
class CentralMonitorPage extends Page
    constructor: (@sd, @switch_to_page) ->
        super "centralmonitorpage-", "html/centralmonitorpage.html"
        
        $(@sd.centers).on "updated", (e, source) =>
            @vm.devices_store = @subitems_store()
            @vm.devices_server = @subitems_server()
            @tree(@vm.devices_store,@vm.devices_server,this,@sd)
            
        $(@sd.stats).on "updated", (e, source) =>
            if @has_rendered
                latest = source.items[source.items.length-1]
        @vm.show_tree_1 = false
        
    define_vm: (vm) =>
        vm.lang = lang.centralmonitor
        vm.search = @search
        vm.detail = @detail
        vm.rendered = @rendered
        vm.unmonitor = @unmonitor
        vm.devices_store = @subitems_store()
        vm.devices_server = @subitems_server()
        vm.switch_to_page = @switch_to_page
        vm.test = @test
        vm.manual = @manual
        vm.fattr_machine_status = fattr.machine_status
        vm.server_navs = "192.168.2.149"
        vm.tab_click_store = @tab_click_store
        vm.tab_click_server = @tab_click_server
        vm.show_tree_1 = false
        
    rendered: () =>
        super()
        $('.tooltips').tooltip()
        $("form.machines").validate(
            valid_opt(
                rules:
                    'machine-checkbox':
                        required: true
                        minlength: 1
                messages:
                    'machine-checkbox': "请选择至少一个虚拟磁盘"))
        @vm.devices_store = @subitems_store()
        @vm.devices_server = @subitems_server()
        @tree(@vm.devices_store,@vm.devices_server,this,@sd)
    
    tree: (store,server,page,sd) =>
        console.log store
        console.log server
        $(`function () {
            var _ref;
            tree_store = [];
            for (var i=0;i< store.length;i++){
                _ref = store[i];
                var chinese_health;
                if (_ref.health){
                   chinese_health = "在线"
                }
                else{
                   chinese_health = "掉线"
                }
                if (_ref.name == "(请添加)"){
                   _ref.devtype = "storage"
                }
                tree_store.push({"name": _ref.name,
                                 "parent": server[0].name,
                                 "health":_ref.health,
                                 "chinese_health":chinese_health,
                                 "devtype":_ref.devtype,
                                 "slotnr": _ref.slotnr,
                                 "uuid":_ref.uuid});
            };
            var chinese_health_server;
            if (server[0].health){
                chinese_health_server = "在线"
            }
            else{
                chinese_health_server = "掉线"
            }
            if (server[0].name == "(请添加)"){
                server[0].devtype = "export"
            }
            var treeData = [
              {
                "name": server[0].name,
                "health":server[0].health,
                "chinese_health":chinese_health_server,
                "devtype":server[0].devtype,
                "slotnr": server[0].slotnr,
                "uuid":server[0].uuid,
                "parent": "null",
                "children": tree_store
              }
            ];
            
            // ************** Generate the tree diagram  *****************
            var margin = {top: 20, right: 120, bottom: 20, left: 120},
                width = 960 - margin.right - margin.left,
                height = 500 - margin.top - margin.bottom;
            
            var i = 0,
                duration = 750,
                root;
            
            var tree = d3.layout.tree()
                .size([height, width]);
            
            var diagonal = d3.svg.diagonal()
                .projection(function(d) { return [d.y, d.x]; });
            
            var svg = d3.select("#body").append("svg")
                .attr("width", width + margin.right + margin.left)
                .attr("height", height + margin.top + margin.bottom)
              .append("g")
                .attr("transform", "translate(" + margin.left + "," + margin.top + ")");
            
            root = treeData[0];
            root.x0 = height / 2;
            root.y0 = 0;
            
            update(root);
            
            // d3.select(self.frameElement).style("height", "500px");
            
            function update(source) {
            
              // Compute the new tree layout.
              var nodes = tree.nodes(root).reverse(),
                  links = tree.links(nodes);
            
              // Normalize for fixed-depth.线条长度
              nodes.forEach(function(d) { d.y = d.depth * 280; });
            
              // Update the nodes…
              var node = svg.selectAll("g.node")
                  .data(nodes, function(d) { return d.id || (d.id = ++i); });
                  
              //tooltip
              var tooltip = d3.select("body")
                  .append("div")
                  .attr("class","tooltip_tree")
                  .style("opacity",0.0);
                  
              /*var remove = d3.select("#body")
                  .html('地址:')
                  .append("div")
                  .attr("class","tooltip_tree")
                  .style("opacity",1.0)
                  .style("left", 1000 + "px")
                  .style("top", 1000 + "px");*/
                  
              // Enter any new nodes at the parent's previous position.
              var nodeEnter = node.enter().append("g")
                  .attr("class", "node")
                  .attr("transform", function(d) { return "translate(" + source.y0 + "," + source.x0 + ")"; })
                  .on("click", click)
                  .on("mouseover",function(d){
                        if (d.name == "(请添加)"){
                            tooltip.html(d.name)
                                .style("left", (d3.event.pageX) + "px")
                                .style("top", (d3.event.pageY + 20) + "px")
                                .style("opacity",1.0);
                        }
                        else{
                            tooltip.html('地址:' + d.name + '</br>' + '状态:' + d.chinese_health)
                                .style("left", (d3.event.pageX) + "px")
                                .style("top", (d3.event.pageY + 20) + "px")
                                .style("opacity",1.0);
                        }
                  })
                  .on("mousemove",function(d){
                        tooltip.style("left", (d3.event.pageX) + "px")
                                .style("top", (d3.event.pageY + 20) + "px");
                  })
                  .on("mouseout",function(d){
                        tooltip.style("opacity",0.0);
                  });
                    
              nodeEnter.append("circle")
                  .attr("r", 1e-6)
                  .style("fill", function(d) { 
                        if( d.health){
                            return d._children ? "lightsteelblue" : "#3cc051"; 
                        }
                        else{
                            return d._children ? "lightsteelblue" : "rgb(214, 70, 53)"; 
                        }
                });
                
              nodeEnter.append("image")
                    .attr("x", function(d) { return d.children || d._children ? -66 : 23; })
                    .attr("y", "-30px") 
                    .attr("width",50)  
                    .attr("height",50)  
                    .style("cursor", "pointer")
                    .attr("xlink:href",function(d) {
                        if(d.devtype == "storage"){
                            return "images/d3/networking.png"
                        }else{
                            return "images/d3/computer-1.png"
                        }
                    })
                    .on("click", function(d) {
                        tooltip.html(d.name)
                            .style("opacity",0.0);
                        if (d.name == "(请添加)"){
                            return click(d);
                        }
                        if (d.devtype == "export"){
                            return (new CentralServerDetailPage(sd,page,d, page.switch_to_page,d.uuid)).attach();
                        }
                        else{
                            page.frozen();
                            chain = new Chain();
                            chain.chain((function() {
                              return function() {
                                return (new MachineRest(sd.host)).refresh_detail(d.uuid);
                              };
                            })(page));
                            chain.chain(sd.update("all"));
                            return show_chain_progress(chain).done((function() {
                              return function() {
                                page.attach();
                                return page.detail(d);
                              };
                            })(page));
                        }
                  });
                    
              nodeEnter.append("text")
                  .attr("x", function(d) { 
                           if(d.name == "(请添加)"){
                             return d.children || d._children ? -22 : 25; 
                           }else{
                             return d.children || d._children ? -10 : 83; 
                           }
                        })
                  .attr("y", function(d) { 
                           if(d.name == "(请添加)"){
                             return d.children || d._children ? 38 : 38; 
                           }else{
                             return d.children || d._children ? 38 : 0; 
                           } 
                   })
                  .attr("text-anchor", function(d) { return d.children || d._children ? "end" : "start"; })
                  //.text(function(d) {})
                  .text(function(d) { return d.name; })
                  .style("fill-opacity", 1e-6)
                  .on("click", function(d) {
                        tooltip.html(d.name)
                            .style("opacity",0.0);
                        if (d.name == "(请添加)"){
                            return click(d);
                        }
                        if (d.devtype == "export"){
                            return (new CentralServerDetailPage(sd,page,d, page.switch_to_page,d.uuid)).attach();
                        }
                        else{
                            page.frozen();
                            chain = new Chain();
                            chain.chain((function() {
                              return function() {
                                return (new MachineRest(sd.host)).refresh_detail(d.uuid);
                              };
                            })(page));
                            chain.chain(sd.update("all"));
                            return show_chain_progress(chain).done((function() {
                              return function() {
                                page.attach();
                                return page.detail(d);
                              };
                            })(page));
                        }
                  });
                  
              /*
              //add icon
              nodeEnter.append("svg:foreignObject")
                  .attr("width", 50)
                  .attr("height", 50)
                  .attr("y", "-16px")
                  .attr("x", function(d) { return d.children || d._children ? -66 : 23; })
                .append("xhtml:span")
                    .attr("class", function(d){
                        if(d.devtype == "storage"){
                            return "icon_storage icon-laptop";
                        }
                        else{
                            return "icon_export icon-desktop";
                        }
                    });*/
               /*
               //add status span
               nodeEnter.append("svg:foreignObject")
                  .attr("width", 50)
                  .attr("height", 50)
                  .attr("y", "-16px")
                  .attr("x", function(d) { return d.children || d._children ? -126 : 63; })
                .append("xhtml:span")
                    .attr("class", function(d){
                        if(d.health){
                            return "span_success";
                        }
                        else{
                            return "span_warning";
                        }})
                    .text(function(d) {
                        if (d.health){
                            return "在线";
                        }
                        else{
                            return "掉线";
                    }});*/
                    
              // Transition nodes to their new position.
              var nodeUpdate = node.transition()
                  .duration(duration)
                  .attr("transform", function(d) { return "translate(" + d.y + "," + d.x + ")"; });
            
              nodeUpdate.select("circle")
                  .attr("r", 5)
                  .style("fill", function(d) { 
                        if( d.health){
                            return d._children ? "lightsteelblue" : "#3cc051"; 
                        }
                        else{
                            return d._children ? "lightsteelblue" : "rgb(214, 70, 53)"; 
                        }
                });
            
              nodeUpdate.select("text")
                  .style("fill-opacity", 1);
            
              // Transition exiting nodes to the parent's new position.
              var nodeExit = node.exit().transition()
                  .duration(duration)
                  .attr("transform", function(d) { return "translate(" + source.y + "," + source.x + ")"; })
                  .remove();
            
              nodeExit.select("circle")
                  .attr("r", 1e-6);
            
              nodeExit.select("text")
                  .style("fill-opacity", 1e-6);
            
              // Update the links…
              var link = svg.selectAll("path.link")
                  .data(links, function(d) { return d.target.id; });
            
              // Enter any new links at the parent's previous position.
              link.enter().insert("path", "g")
                  .attr("class", "link")
                  .attr("d", function(d) {
                    var o = {x: source.x0, y: source.y0};
                    return diagonal({source: o, target: o});
                  });
            
              // Transition links to their new position.
              link.transition()
                  .duration(duration)
                  .attr("d", diagonal);
            
              // Transition exiting nodes to the parent's new position.
              link.exit().transition()
                  .duration(duration)
                  .attr("d", function(d) {
                    var o = {x: source.x, y: source.y};
                    return diagonal({source: o, target: o});
                  })
                  .remove();
            
              // Stash the old positions for transition.
              nodes.forEach(function(d) {
                d.x0 = d.x;
                d.y0 = d.y;
              });
            }
            
            // Toggle children on click.
            function click(d) {
              if (d.children) {
                d._children = d.children;
                d.children = null;
              } else {
                d.children = d._children;
                d._children = null;
              }
              update(d);
            }
        }`)   
        
    tab_click_store: (e) =>
        #console.log e
        #index = parseInt e.currentTarget.dataset.idx
        device = e.currentTarget.$vmodel.e.$model
        if device.name is "(请添加)" or !device.health
            return
        if e.target.className isnt "icon-close"
            @frozen()
            chain = new Chain()
            chain.chain(=> (new MachineRest(@sd.host)).refresh_detail(device.uuid))
            chain.chain @sd.update("all")
            show_chain_progress(chain).done =>
                @attach()
                @detail device
        else
            @unmonitor device
            
    tab_click_server: (e) =>
        #console.log e
        #index = parseInt e.currentTarget.dataset.idx
        device = e.currentTarget.$vmodel.t.$model
        if e.target.className isnt "icon-close"
            @detail device
        else
            @unmonitor device
            
    test: () =>
        chain = new Chain()
        tlist = (new MachineRest(@sd.host))
        (tlist.query()).done (data) =>
            console.log data
    
    manual: () =>
        (new CentralManualModal @sd,this).attach()
        
    search: () =>
        outline = []
        chain = new Chain()
        bcst = new BCST
        chain.chain bcst.broadcast
        show_chain_progress(chain).done =>
            machines = bcst.getMachines().reverse()
            @_search(machines).sort(@_compare('num'))
            if machines
                if @sd.centers.items != null
                    online = [i.Ip for i in @sd.centers.items]
                    for i in machines
                        if i.ifaces[0] not in online[0]
                            outline.push i
                    if outline.length > 0
                        console.log this
                        (new CentralSearchModal @sd, this, outline, "storage" ,(data)=>
                            @frozen()
                        ).attach()
                    else
                        (new MessageModal (lang.centralview.detect_no_new_machine_info)).attach()
                else
                    console.log machines
                    (new CentralSearchModal @sd, this, machines, "storage" ,(data)=>
                        @frozen()
                    ).attach()
            else
                (new MessageModal (lang.centralview.detect_no_machines_info)).attach()

    _search: (machines) =>
        for i in machines
            i.num = Number(i.ifaces[0].split('.')[3])
        return  machines
    
    subitems_store: () =>
        if @_subitems_store().length
            all_devices = @get_devices @_subitems_store()
            return all_devices
        return [{name:"(请添加)",health:true}]
        
    subitems_server: () =>
        if @_subitems_server().length
            all_devices = @get_devices @_subitems_server()
            return all_devices
        return [{name:"(请添加)",health:true}]
        
    _subitems_store: () =>
        if @sd.centers.items != null
            tmp = []
            items = subitems @sd.centers.items, Uuid:"", Ip:"", Slotnr:"", Created: "",Devtype:"",Status:""
            ((tmp.push i) for i in items when i.Devtype is "storage")
            tmp
            
    _subitems_server: () =>
        if @sd.centers.items != null
            tmp = []
            items = subitems @sd.centers.items, Uuid:"", Ip:"", Slotnr:"", Created: "",Devtype:"",Status:""
            ((tmp.push i) for i in items when i.Devtype is "export")
            tmp
            
    get_history_devices: () =>
        tlist = (new MachineRest(@sd.host))
        (tlist.query()).done (data) =>
            if data.detail != null
                machines = @translate data.detail
                all_devices = @get_devices machines
                @vm.devices = all_devices            

    translate: (detail) =>  
        machines = []
        ((machines.push i.Ip) for i in detail when i.Ip not in machines)
        machines

    detail: (device) =>
        if device.name is '(请添加)' or !device.health
            return
        if device.devtype is "storage"
            (new CentralStoreDetailPage @sd,this,device,@switch_to_page,device.uuid).attach()
        else
            (new CentralServerDetailPage @sd,this,device,@switch_to_page,device.uuid).attach()
            
    unmonitor: () =>
        (new CentralUnmonitorModal @sd, this ).attach()
        ###
        if device.name is '(请添加)'
            return
        (new ConfirmModal(@vm.lang.unmonitor_tips, =>
                @frozen()
                chain = new Chain()
                chain.chain(=> (new MachineRest(@sd.host)).unmonitor(device.uuid))
                chain.chain @sd.update("all")
                show_chain_progress(chain).done =>
                    @attach()
                    (new MessageModal @vm.lang.unmonitor_success).attach()
        )).attach()###
            
    _filter_machine: (bcst) =>
        machines = bcst.getDetachMachines()
        shown_machines = @_get_shown_machies()
        temp_machines = []
        isLoged = false
        temp = []
        for machine in machines
            for addr in machine
                if addr in shown_machines
                    isLoged = true
                    break
            if not isLoged
                temp_machines.push machine
            isLoged = false
        machines = []
        for machine in temp_machines
            is_add = false
            if machines.length is 0
                machines.push machine
                continue
            for temp in machines
                if temp[0] in machine
                    is_add = true
                    break
            machines.push machine if not is_add        
        temp_machines = []
        for machine in machines
            for addr in machine
                if bcst.isContained addr
                    temp_machines.push addr
                    break
        temp_machines        
        
    _get_shown_machies: =>
        machines = []
        regex = /^\d{1,3}(\.\d{1,3}){3}$/
        settings = new SettingsManager
        if settings.getSearchedMachines() and settings.getSearchedMachines().length != 0
            for machine in settings.getSearchedMachines()
                machines.push machine if regex.test machine
        machines     

                
    get_devices: (machines) =>
        slotgroups = []
        slotgroup = []
        slot = []
        count = 0
        on_monitor = []
        for i in machines.sort(@compare('Ip'))
            o = @_get_devices i.Ip
            o.num = Number(i.Ip.split('.')[3])
            o.uuid = i.Uuid
            o.name = i.Ip
            o.slotnr = i.Slotnr
            o.created = i.Created
            o.health = i.Status
            o.devtype = i.Devtype
            slot.push o
        slots = @compare(slot)
        return slots

    _get_devices: (machine) =>
        #regex = /(\d{1,3})$/
        regex = /\d{1,3}(\.\d{1,3})$/
        temp = machine.match(regex)[0]
        if temp.length == 4
            gap = '.0'
            result = temp.split('.').join(gap)
        else if temp.length == 3
            gap = '.00'
            result = temp.split('.').join(gap)
        else
            result = temp
        return ip:result

    compare: (machines) =>
        failed = []
        degraded = []
        normal = []
        for i in machines
            switch i.health
                when true
                    normal.push i
                when  false
                    failed.push i
                when 'degraded'
                    degraded.push i
        failed = failed.sort(@_compare('ip'))
        degraded = degraded.sort(@_compare('ip'))
        normal = normal.sort(@_compare('num'))
        return failed.concat(degraded).concat(normal)

    _compare: (propertyname) =>
        (obj1, obj2) =>
            value1 = obj1[propertyname]
            value2 = obj2[propertyname]
            if value1 < value2
                return -1
            else if value1 > value2
                return 1
            else 
                return 0

    test_1: () =>
        return [[{raid: "normal",raidcolor: "color0",role: "unused",slot:"1"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"2"},\
        {raid: "normal",raidcolor: "color0",role: "unused",slot:"3"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"4"}],\
        [{raid: "normal",raidcolor: "color0",role: "unused",slot:"5"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"6"},\
        {raid: "normal",raidcolor: "color0",role: "unused",slot:"7"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"8"}],\
        [{raid: "normal",raidcolor: "color0",role: "unused",slot:"9"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"10"},\
        {raid: "normal",raidcolor: "color0",role: "unused",slot:"11"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"12"}],\
        [{raid: "normal",raidcolor: "color0",role: "unused",slot:"13"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"14"},\
        {raid: "normal",raidcolor: "color0",role: "unused",slot:"15"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"16"}]]
        
class CentralStoremonitorPage extends Page
    constructor: (@sd, @switch_to_page) ->
        super "centralstoremonitorpage-", "html/centralstoremonitorpage.html"
        #@host = "192.168.2.193:8080"
        $(@sd.centers).on "updated", (e, source) =>
            @vm.devices = @subitems()
            
        $(@sd.stats).on "updated", (e, source) =>
            if @has_rendered
                latest = source.items[source.items.length-1]
                
    define_vm: (vm) =>
        vm.lang = lang.centralstoremonitor
        vm.search = @search
        vm.detail = @detail
        vm.rendered = @rendered
        vm.unmonitor = @unmonitor
        #vm.test = [{ip:"2.88"},{ip:"2.110"}]
        #vm.devices = [[{ip:"请扫描"},{ip:"请扫描"},{ip:"请扫描"},{ip:"请扫描"}],[{ip:"请扫描"},{ip:"请扫描"},{ip:"请扫描"},{ip:"请扫描"}]]
        vm.devices = @subitems()
        vm.switch_to_page = @switch_to_page
        vm.test = @test
        vm.manual = @manual
        vm.fattr_machine_status = fattr.machine_status
        vm.server_navs = "192.168.2.149"
        #vm.store_navs = @store_navs()
        
    rendered: () =>
        super()
        $('.tooltips').tooltip()
        $("form.machines").validate(
            valid_opt(
                rules:
                    'machine-checkbox':
                        required: true
                        minlength: 1
                messages:
                    'machine-checkbox': "请选择至少一个虚拟磁盘"))
        @vm.devices = @subitems()
    
    test: () =>
        chain = new Chain()
        tlist = (new MachineRest(@sd.host))
        (tlist.query()).done (data) =>
            console.log data
    
    manual: () =>
        (new CentralManualModal @sd,this,"storage").attach()
        
    search: () =>
        outline = []
        chain = new Chain()
        bcst = new BCST
        chain.chain bcst.broadcast
        show_chain_progress(chain).done =>
            machines = bcst.getMachines().reverse()
            @_search(machines).sort(@_compare('num'))
            if machines
                if @sd.centers.items != null
                    online = [i.Ip for i in @sd.centers.items]
                    for i in machines
                        if i.ifaces[0] not in online[0]
                            outline.push i
                    if outline.length > 0
                        console.log this
                        (new CentralSearchModal @sd, this, outline, "storage" ,(data)=>
                            @frozen()
                        ).attach()
                    else
                        (new MessageModal (lang.centralview.detect_no_new_machine_info)).attach()
                else
                    console.log machines
                    (new CentralSearchModal @sd, this, machines, "storage" ,(data)=>
                        @frozen()
                    ).attach()
            else
                (new MessageModal (lang.centralview.detect_no_machines_info)).attach()

    _search: (machines) =>
        for i in machines
            i.num = Number(i.ifaces[0].split('.')[3])
        return  machines
    
    subitems: () =>
        if @_subitems().length
            all_devices = @get_devices @_subitems()
            return all_devices[0]
        return [[{name:"请添加",health:true}]]

    _subitems: () =>
        if @sd.centers.items != null
            tmp = []
            items = subitems @sd.centers.items, Uuid:"", Ip:"", Slotnr:"", Created: "",Devtype:"",Status:""
            ((tmp.push i) for i in items when i.Devtype is "storage")
            tmp

    get_history_devices: () =>
        tlist = (new MachineRest(@sd.host))
        (tlist.query()).done (data) =>
            if data.detail != null
                machines = @translate data.detail
                all_devices = @get_devices machines
                @vm.devices = all_devices            

    translate: (detail) =>  
        machines = []
        ((machines.push i.Ip) for i in detail when i.Ip not in machines)
        machines

    detail: (device) =>
        if device.name is '请添加' or !device.health
            return
        (new CentralStoreDetailPage @sd,this,device,@switch_to_page).attach()
          
    unmonitor: (device) =>
        if device.name is '请添加'
            return
        (new ConfirmModal(@vm.lang.unmonitor_tips, =>
                @frozen()
                chain = new Chain()
                chain.chain(=> (new MachineRest(@sd.host)).unmonitor(device.uuid))
                chain.chain @sd.update("all")
                show_chain_progress(chain).done =>
                    @attach()
                    (new MessageModal @vm.lang.unmonitor_success).attach()
        )).attach()
            
    _filter_machine: (bcst) =>
        machines = bcst.getDetachMachines()
        shown_machines = @_get_shown_machies()
        temp_machines = []
        isLoged = false
        temp = []
        for machine in machines
            for addr in machine
                if addr in shown_machines
                    isLoged = true
                    break
            if not isLoged
                temp_machines.push machine
            isLoged = false
        machines = []
        for machine in temp_machines
            is_add = false
            if machines.length is 0
                machines.push machine
                continue
            for temp in machines
                if temp[0] in machine
                    is_add = true
                    break
            machines.push machine if not is_add        
        temp_machines = []
        for machine in machines
            for addr in machine
                if bcst.isContained addr
                    temp_machines.push addr
                    break
        temp_machines        
        
    _get_shown_machies: =>
        machines = []
        regex = /^\d{1,3}(\.\d{1,3}){3}$/
        settings = new SettingsManager
        if settings.getSearchedMachines() and settings.getSearchedMachines().length != 0
            for machine in settings.getSearchedMachines()
                machines.push machine if regex.test machine
        machines     

                
    get_devices: (machines) =>
        slotgroups = []
        slotgroup = []
        slot = []
        count = 0
        on_monitor = []
        for i in machines.sort(@compare('Ip'))
            o = @_get_devices i.Ip
            o.num = Number(i.Ip.split('.')[3])
            o.uuid = i.Uuid
            o.name = i.Ip
            o.slotnr = i.Slotnr
            o.created = i.Created
            o.health = i.Status
            slot.push o
        slots = @compare(slot)
        for i in slots
            count += 1
            slotgroup.push i
            if machines.length is count or count%4 is 0
                slotgroups.push slotgroup
                slotgroup = []
        return slotgroups

    _get_devices: (machine) =>
        #regex = /(\d{1,3})$/
        regex = /\d{1,3}(\.\d{1,3})$/
        temp = machine.match(regex)[0]
        if temp.length == 4
            gap = '.0'
            result = temp.split('.').join(gap)
        else if temp.length == 3
            gap = '.00'
            result = temp.split('.').join(gap)
        else
            result = temp
        return ip:result

    compare: (machines) =>
        failed = []
        degraded = []
        normal = []
        for i in machines
            switch i.health
                when true
                    normal.push i
                when  false
                    failed.push i
                when 'degraded'
                    degraded.push i
        failed = failed.sort(@_compare('ip'))
        degraded = degraded.sort(@_compare('ip'))
        normal = normal.sort(@_compare('num'))
        return failed.concat(degraded).concat(normal)

    _compare: (propertyname) =>
        (obj1, obj2) =>
            value1 = obj1[propertyname]
            value2 = obj2[propertyname]
            if value1 < value2
                return -1
            else if value1 > value2
                return 1
            else 
                return 0

    test_1: () =>
        return [[{raid: "normal",raidcolor: "color0",role: "unused",slot:"1"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"2"},\
        {raid: "normal",raidcolor: "color0",role: "unused",slot:"3"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"4"}],\
        [{raid: "normal",raidcolor: "color0",role: "unused",slot:"5"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"6"},\
        {raid: "normal",raidcolor: "color0",role: "unused",slot:"7"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"8"}],\
        [{raid: "normal",raidcolor: "color0",role: "unused",slot:"9"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"10"},\
        {raid: "normal",raidcolor: "color0",role: "unused",slot:"11"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"12"}],\
        [{raid: "normal",raidcolor: "color0",role: "unused",slot:"13"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"14"},\
        {raid: "normal",raidcolor: "color0",role: "unused",slot:"15"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"16"}]]
        
        
class CentralServermonitorPage extends Page
    constructor: (@sd, @switch_to_page) ->
        super "centralservermonitorpage-", "html/centralservermonitorpage.html"
        #@host = "192.168.2.193:8080"
        $(@sd.centers).on "updated", (e, source) =>
            @vm.devices = @subitems()
        
        $(@sd.stats).on "updated", (e, source) =>
            if @has_rendered
                latest = source.items[source.items.length-1]
                
    define_vm: (vm) =>
        vm.lang = lang.centralservermonitor
        vm.search = @search
        vm.detail = @detail
        vm.rendered = @rendered
        vm.unmonitor = @unmonitor
        #vm.test = [{ip:"2.88"},{ip:"2.110"}]
        #vm.devices = [[{ip:"请扫描"},{ip:"请扫描"},{ip:"请扫描"},{ip:"请扫描"}],[{ip:"请扫描"},{ip:"请扫描"},{ip:"请扫描"},{ip:"请扫描"}]]
        vm.devices = @subitems()
        vm.switch_to_page = @switch_to_page
        vm.test = @test

    rendered: () =>
        super()
        $('.tooltips').tooltip()
        $("form.machines").validate(
            valid_opt(
                rules:
                    'machine-checkbox':
                        required: true
                        minlength: 1
                messages:
                    'machine-checkbox': "请选择至少一个虚拟磁盘"))
        @vm.devices = @subitems()
    test: () =>
        chain = new Chain()
        tlist = (new MachineRest(@sd.host))
        (tlist.query()).done (data) =>
            console.log data
    
    search: () =>
        outline = []
        chain = new Chain()
        bcst = new BCST
        chain.chain bcst.broadcast
        show_chain_progress(chain).done =>
            machines = bcst.getMachines().reverse()
            @_search(machines).sort(@_compare('num'))
            if machines
                if @sd.centers.items != null
                    online = [i.Ip for i in @sd.centers.items]
                    for i in machines
                        if i.ifaces[0] not in online[0]
                            outline.push i
                    if outline.length > 0
                        console.log this
                        (new CentralSearchModal @sd, this, outline, "export",(data)=>
                            @frozen()
                        ).attach()
                    else
                        (new MessageModal (lang.centralview.detect_no_new_machine_info)).attach()
                else
                    (new CentralSearchModal @sd, this, machines, "export" ,(data)=>
                        @frozen()
                    ).attach()
            else
                (new MessageModal (lang.centralview.detect_no_machines_info)).attach()
                
    _search: (machines) =>
        for i in machines
            i.num = Number(i.ifaces[0].split('.')[3])
        return  machines
    
    subitems: () =>
        if @_subitems().length
            all_devices = @get_devices @_subitems()
            return all_devices
        return [[{name:"请添加",health:true}]]
        
    _subitems: () =>
        if @sd.centers.items != null
            tmp = []
            items = subitems @sd.centers.items, Uuid:"", Ip:"", Slotnr:"", Created: "",Devtype:"",Status:""
            ((tmp.push i) for i in items when i.Devtype is "export")
            tmp

    get_history_devices: () =>
        tlist = (new MachineRest(@sd.host))
        (tlist.query()).done (data) =>
            if data.detail != null
                machines = @translate data.detail
                all_devices = @get_devices machines
                @vm.devices = all_devices            

    translate: (detail) =>  
        machines = []
        ((machines.push i.Ip) for i in detail when i.Ip not in machines)
        machines

    detail: (device) =>
        if device.name is '请添加' or !device.health
            return
        query = (new MachineRest(@sd.host))
        machine_detail = query.machine device.uuid
        machine_detail.done (data) =>
            console.log data
            if data.status is 'success'
                (new CentralServerDetailPage @sd,this,device,@switch_to_page, data.detail).attach()
            else
                (new MessageModal @vm.lang.detail_error).attach()
        
    unmonitor: (device) =>
        if device.name is '请添加'
            return
        (new ConfirmModal(@vm.lang.unmonitor_tips, =>
            @frozen()
            chain = new Chain()
            chain.chain(=> (new MachineRest(@sd.host)).unmonitor(device.uuid))
            chain.chain @sd.update("all")
            show_chain_progress(chain).done =>
                @attach()
                (new MessageModal @vm.lang.unmonitor_success).attach()
        )).attach()
        
    _filter_machine: (bcst) =>
        machines = bcst.getDetachMachines()
        shown_machines = @_get_shown_machies()
        temp_machines = []
        isLoged = false
        temp = []
        for machine in machines
            for addr in machine
                if addr in shown_machines
                    isLoged = true
                    break
            if not isLoged
                temp_machines.push machine
            isLoged = false
        machines = []
        for machine in temp_machines
            is_add = false
            if machines.length is 0
                machines.push machine
                continue
            for temp in machines
                if temp[0] in machine
                    is_add = true
                    break
            machines.push machine if not is_add        
        temp_machines = []
        for machine in machines
            for addr in machine
                if bcst.isContained addr
                    temp_machines.push addr
                    break
        temp_machines        
        
    _get_shown_machies: =>
        machines = []
        regex = /^\d{1,3}(\.\d{1,3}){3}$/
        settings = new SettingsManager
        if settings.getSearchedMachines() and settings.getSearchedMachines().length != 0
            for machine in settings.getSearchedMachines()
                machines.push machine if regex.test machine
        machines        
        
                
    get_devices: (machines) =>
        slotgroups = []
        slotgroup = []
        slot = []
        count = 0
        on_monitor = []
        for i in machines.sort(@compare('Ip'))
            o = @_get_devices i.Ip
            o.num = Number(i.Ip.split('.')[3])
            o.uuid = i.Uuid
            o.name = i.Ip
            o.slotnr = i.Slotnr
            o.created = i.Created
            o.health = i.Status
            slot.push o
        slots = @compare(slot)
        for i in slots
            count += 1
            slotgroup.push i
            if machines.length is count or count%4 is 0
                slotgroups.push slotgroup
                slotgroup = []
        return slotgroups

    _get_devices: (machine) =>
        #regex = /(\d{1,3})$/
        regex = /\d{1,3}(\.\d{1,3})$/
        temp = machine.match(regex)[0]
        if temp.length == 4
            gap = '.0'
            result = temp.split('.').join(gap)
        else if temp.length == 3
            gap = '.00'
            result = temp.split('.').join(gap)
        else
            result = temp
        return ip:result

    compare: (machines) =>
        failed = []
        degraded = []
        normal = []
        for i in machines
            switch i.health
                when  true
                    normal.push i
                when  false
                    failed.push i
                when  'degraded'
                    degraded.push i
        failed = failed.sort(@_compare('ip'))
        degraded = degraded.sort(@_compare('ip'))
        normal = normal.sort(@_compare('num'))
        return failed.concat(degraded).concat(normal)

    _compare: (propertyname) =>
        (obj1, obj2) =>
            value1 = obj1[propertyname]
            value2 = obj2[propertyname]
            if value1 < value2
                return -1
            else if value1 > value2
                return 1
            else 
                return 0

    test_1: () =>
        return [[{raid: "normal",raidcolor: "color0",role: "unused",slot:"1"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"2"},\
        {raid: "normal",raidcolor: "color0",role: "unused",slot:"3"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"4"}],\
        [{raid: "normal",raidcolor: "color0",role: "unused",slot:"5"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"6"},\
        {raid: "normal",raidcolor: "color0",role: "unused",slot:"7"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"8"}],\
        [{raid: "normal",raidcolor: "color0",role: "unused",slot:"9"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"10"},\
        {raid: "normal",raidcolor: "color0",role: "unused",slot:"11"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"12"}],\
        [{raid: "normal",raidcolor: "color0",role: "unused",slot:"13"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"14"},\
        {raid: "normal",raidcolor: "color0",role: "unused",slot:"15"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"16"}]]
        


class CentralStoreDetailPage extends Page
    constructor: (@sd, @page, @device, @switch_to_page, @message) ->
        super "centralstoredetailpage-", "html/centralstoredetailpage.html"
        
        $(@sd.stats).on "updated", (e, source) =>
            if @has_rendered
                latest = source.items[source.items.length-1]
                for i in latest.storages
                    if i.ip is @device.name
                        @vm.cpu_load = parseInt i.info[0].cpu
                        @vm.mem_load = parseInt i.info[0].mem
                        @vm.system = parseInt i.info[0].df[0].used_per
                        @vm.temp = parseInt i.info[0].temp
                        
                        if i.info[0].cache_total is 0
                            @vm.cache_load = 0
                        else
                            @vm.cache_load = parseInt(i.info[i.info.length - 1].cache_used/i.info[i.info.length - 1].cache_total)
                            
                        if i.info[0].df.length is 2
                            @vm.cap = parseInt i.info[0].df[1].used_per
                        else
                            @vm.cap = 0
                        
                        #system = parseInt i.info[i.info.length - 1].df[0].used_per
                        #cap = parseInt i.info[i.info.length - 1].df[1].used_per
                        #temp = parseInt i.info[i.info.length - 1].temp
                        #@sparkline_stats system,temp,cap
                        #@refresh_flow()
                        
        $(@sd.journals).on "updated", (e, source) =>
            @vm.journal = @subitems_log()
            
        $(@sd.machinedetails).on "updated", (e, source) =>
            if @has_rendered
                for i in source.items
                    if i.uuid is @device.uuid
                        array_slot = []
                        array_journal = []
                        if i.disks.length > 0
                            array_slot = i.disks
                        details = @query_list array_slot
                        slot = @get_slots details
                        array_journal = i.journals
                        
                        @vm.slots = slot
                        @vm.raids = i.raids
                        @vm.volumes = i.volumes
                        
                for t in array_journal
                    t.created = t.created.replace("-","/").replace("-","/").replace("T","-").replace("+08:00","")
                    if t.status
                        t.chinese_status = "handled"
                    else
                        t.chinese_status = "unhandled"
                        
                for j in array_slot
                    if j.raid is ""
                        j.raid = "无"
                @vm.journal = array_journal.reverse()
                @vm.disks = array_slot
            
    define_vm: (vm) =>
        vm.lang = lang.centraldisk
        vm.slots = @slots()
        vm.flow_type = "fwrite_mb"
        vm.disks = @disks()
        vm.raids = @raids()
        vm.volumes = @volumes()
        vm.filesystems = @filesystems()
        #vm.initiators = @initiators()
        #vm._smarts = @_smarts()
        #vm.raids = @_subitems()
        #vm.smarts = @smarts()
        #vm.smget = @smget
        #vm.smart = @smarts()[0].smartinfo
        vm.fattr_health = fattr.health
        vm.fattr_role = fattr.role
        vm.fattr_cap = fattr.cap
        vm.fattr_caps = fattr.caps
        vm.fattr_disk_status = fattr.disk_status
        vm.fattr_view_status_fixed = fattr.view_status_fixed
        vm.disk_list = @disk_list
        vm.need_format = false
        vm.switch_to_page = @switch_to_page
        vm.navs = [{title: lang.centralsidebar.overview, icon: "icon-dashboard", id: "overview"},
                   {title: lang.centralsidebar.server, icon: "icon-wrench",   id: "server"}]
        newid = random_id 'menu-'
        
        vm.navss = [{title: lang.adminview.menu_new, icon: "icon-home", menuid: "#{newid}"}]
        vm.cpu_load = 0
        vm.cache_load = 0
        vm.mem_load = 0
        vm.system = 0
        vm.temp = 0
        vm.cap = 0
        vm.$watch "cpu_load", (nval, oval) =>
            $("#cpu-load").data("easyPieChart").update?(nval) if @has_rendered
            return
        vm.$watch "cache_load", (nval, oval) =>
            $("#cache-load").data("easyPieChart").update?(nval) if @has_rendered
            return
        vm.$watch "mem_load", (nval, oval) =>
            $("#mem-load").data("easyPieChart").update?(nval) if @has_rendered
            return
        vm.tabletitle = @device.name
        
        vm.fattr_journal_status = fattr.journal_status
        vm.journal = @subitems_log()
        vm.journal_info = @subitems_info()
        vm.journal_warning = @subitems_warning()
        vm.journal_critical = @subitems_critical()
        vm.rendered = @rendered

    rendered: () =>
        super()
        #$("[data-toggle='tooltip']").tooltip()
        $('.tooltips').tooltip()
        $ ->
        $("#myTab li:eq(0) a").tab "show"
        $("#smartTab li:eq(0) a").tab "show"
        
        opt1 = animate: 1000, size: 115, lineWidth: 5, lineCap: "butt", barColor: "rgb(255, 184, 72)",trackColor: 'rgba(255, 184, 72,0.1)',scaleColor: false
        opt2 = animate: 1000, size: 115, lineWidth: 5, lineCap: "butt", barColor: "rgb(40, 183, 121)",trackColor: 'rgba(40, 183, 121,0.1)',scaleColor: false
        opt3 = animate: 1000, size: 115, lineWidth: 5, lineCap: "butt", barColor: "rgb(52, 152, 219)",trackColor: 'rgba(52, 152, 219,0.1)',scaleColor: false
        @data_table = $("#table2").dataTable dtable_opt(retrieve: true)
        @data_table = $("#table3").dataTable dtable_opt(retrieve: true)
        @data_table = $("#table4").dataTable dtable_opt(retrieve: true)
        @data_table = $("#table5").dataTable dtable_opt(retrieve: true)
        
        @data_table1 = $("#log-table1").dataTable dtable_opt(retrieve: true, bSort: false,scrollX: true)
        @data_table2 = $("#log-table2").dataTable dtable_opt(retrieve: true, bSort: false,scrollX: true)
        @data_table3 = $("#log-table3").dataTable dtable_opt(retrieve: true, bSort: false,scrollX: true)
        @data_table4= $("#log-table4").dataTable dtable_opt(retrieve: true, bSort: false,scrollX: true)
        $(".dataTables_filter input").addClass "m-wrap small"
        $(".dataTables_length select").addClass "m-wrap small"
        
        $scroller1 = $("#journals-scroller-1")
        $scroller2 = $("#journals-scroller-2")
        $scroller3 = $("#journals-scroller-3")
        $scroller4 = $("#journals-scroller-4")
        
        $scroller1.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller1.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
        $scroller2.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller2.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
        $scroller3.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller3.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
        $scroller4.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller4.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
        $("#cpu-load").easyPieChart opt1
        $("#cpu-load").data("easyPieChart").update? @vm.cpu_load
        $("#cache-load").easyPieChart opt2
        $("#cache-load").data("easyPieChart").update? @vm.cache_load
        $("#mem-load").easyPieChart opt3
        $("#mem-load").data("easyPieChart").update? @vm.mem_load
        
            
        #@refresh_flow()
        #@sparkline_stats 50,10,90
        try
            @plot_flow_in @sd.stats.items,@device.name
            @plot_flow_out @sd.stats.items,@device.name
            @pie_system @sd.stats.items,@device.name
            @pie_temp @sd.stats.items,@device.name
            @pie_cap @sd.stats.items,@device.name
        catch e
            console.log e
        
    subitems_log: () =>
        try
            arrays = []
            for i in @sd.machinedetails.items
                if i.uuid is @message
                   arrays = i.journals
            for t in arrays
                t.created = t.created.replace("-","/").replace("-","/").replace("T","-").replace("+08:00","")
                if t.status
                    t.chinese_status = "handled"
                else
                    t.chinese_status = "unhandled"
            arrays.reverse()
        catch error
            return []
        
    subitems_info: () =>
        info = []
        ((info.push i) for i in @subitems_log() when i.level is 'info')
        info
            
    subitems_warning: () =>
        info = []
        ((info.push i) for i in @subitems_log() when i.level is 'warning')
        info
            
    subitems_critical: () =>
        info = []
        ((info.push i) for i in @subitems_log() when i.level is 'critical')
        info
        
    pie_system: (items,name) =>
        $(`function () {
            $(document).ready(function () {
                Highcharts.setOptions({
                    global: {
                        useUTC: false
                    }
                });
                $('#sparkline_bar1').highcharts({
                    chart: {
                      type: 'pie',
                      margin: [0, 0, 25, 0],
                      events: {
                            load: function () {
                                var series1 = this.series[0];
                                setInterval(function () {
                                    try{
                                        for (var i=0;i< items[items.length - 1].storages.length;i++){
                                            if( items[items.length - 1].storages[i].ip == name){
                                                y = items[items.length - 1].storages[i].info[0].df[0].used_per;
                                            }
                                        };
                                        series1.setData([['已用',y], ['剩余',100 - y]]);
                                    }
                                    catch(e){
                                        console.log(e);
                                    }
                                }, 3000);
                            }
                        }
                    },
                    title: {
                      text: '系统空间',
                      verticalAlign: "bottom",
                      style: {
                        color: '#000',
                        fontFamily: 'Microsoft YaHei',
                        fontSize: 16
                      }
                    },
                    subtitle: {
                      text: ''
                    },
                    xAxis: {
                      type: 'category',
                      gridLineColor: '#FFF',
                      tickColor: '#FFF',
                      labels: {
                        enabled: false,
                        rotation: -45,
                        style: {
                          fontSize: '13px',
                          fontFamily: 'opensans-serif'
                        }
                      }
                    },
                    yAxis: {
                      gridLineColor: '#FFF',
                      min: 0,
                      max: 100,
                      title: {
                        text: ''
                      },
                      labels: {
                        enabled: true
                      }
                    },
                    credits: {
                      enabled: false
                    },
                    exporting: {
                      enabled: false
                    },
                    legend: {
                      enabled: true,
                      backgroundColor: '#FFFFFF',
                      floating: true,
                      align: 'right',
                      layout: 'vertical',
                      verticalAlign: 'top',
                      itemStyle: {
                        color: 'rgb(110,110,110)',
                        fontWeight: '100',
                        fontFamily: "Microsoft YaHei"
                      }
                    },
                    tooltip: {
                      pointFormat: '<b>{point.y:.1f}%</b>',
                      style: {
                        color: '#fff',
                        fontSize: '12px',
                        opacity: 0.8
                      },
                      borderRadius: 0,
                      borderColor: '#000',
                      backgroundColor: '#000'
                    },
                    plotOptions: {
                      pie: {
                        animation: false,
                        shadow: false,
                        borderColor: "rgba(0,0,0,0)",
                        dataLabels: {
                          enabled: false
                        }
                      }
                    },
                    colors: ["rgb(87, 199, 212)", "rgba(87, 199, 212,0.2)"],
                    series: [{
                        name: '系统空间',
                        data: [
                            ['已用',   0],
                            ['剩余',   100]
                        ]
                    }]
                });
            });
        }`);
        
    pie_temp: (items,name) =>
        $(`function () {
            $(document).ready(function () {
                Highcharts.setOptions({
                    global: {
                        useUTC: false
                    }
                });
                $('#sparkline_bar2').highcharts({
                    chart: {
                      type: 'pie',
                      margin: [0, 0, 25, 0],
                      events: {
                            load: function () {
                                var series1 = this.series[0];
                                setInterval(function () {
                                    try{
                                        for (var i=0;i< items[items.length - 1].storages.length;i++){
                                            if( items[items.length - 1].storages[i].ip == name){
                                                y = items[items.length - 1].storages[i].info[0].temp;
                                            }
                                        };
                                        series1.setData([['已用',y], ['剩余',100 - y]]);
                                    }
                                    catch(e){
                                        console.log(e);
                                    }
                                }, 3000);
                            }
                        }
                    },
                    title: {
                      text: '温度',
                      verticalAlign: "bottom",
                      style: {
                        color: '#000',
                        fontFamily: 'Microsoft YaHei',
                        fontSize: 16
                      }
                    },
                    subtitle: {
                      text: ''
                    },
                    xAxis: {
                      type: 'category',
                      gridLineColor: '#FFF',
                      tickColor: '#FFF',
                      labels: {
                        enabled: false,
                        rotation: -45,
                        style: {
                          fontSize: '13px',
                          fontFamily: 'opensans-serif'
                        }
                      }
                    },
                    yAxis: {
                      gridLineColor: '#FFF',
                      min: 0,
                      max: 100,
                      title: {
                        text: ''
                      },
                      labels: {
                        enabled: true
                      }
                    },
                    credits: {
                      enabled: false
                    },
                    exporting: {
                      enabled: false
                    },
                    legend: {
                      enabled: true,
                      backgroundColor: '#FFFFFF',
                      floating: true,
                      align: 'right',
                      layout: 'vertical',
                      verticalAlign: 'top',
                      itemStyle: {
                        color: 'rgb(110,110,110)',
                        fontWeight: '100',
                        fontFamily: "Microsoft YaHei"
                      }
                    },
                    tooltip: {
                      pointFormat: '<b>{point.y:.1f}%</b>',
                      style: {
                        color: '#fff',
                        fontSize: '12px',
                        opacity: 0.8
                      },
                      borderRadius: 0,
                      borderColor: '#000',
                      backgroundColor: '#000'
                    },
                    plotOptions: {
                      pie: {
                        animation: false,
                        shadow: false,
                        borderColor: "rgba(0,0,0,0)",
                        dataLabels: {
                          enabled: false
                        }
                      }
                    },
                    colors: ["rgb(98, 168, 234)", "rgba(98, 168, 234,0.2)"],
                    series: [{
                        name: '温度',
                        data: [
                            ['已用',   0],
                            ['剩余',   100]
                        ]
                    }]
                });
            });
        }`);
        
    pie_cap: (items,name) =>
        $(`function () {
            $(document).ready(function () {
                Highcharts.setOptions({
                    global: {
                        useUTC: false
                    }
                });
                $('#sparkline_bar3').highcharts({
                    chart: {
                      type: 'pie',
                      margin: [0, 0, 25, 0],
                      events: {
                            load: function () {
                                var series1 = this.series[0];
                                setInterval(function () {
                                    try{
                                        for (var i=0;i< items[items.length - 1].storages.length;i++){
                                            if( items[items.length - 1].storages[i].ip == name){
                                                if( items[items.length - 1].storages[i].info[0].df.length == 2){
                                                    y = items[items.length - 1].storages[i].info[0].df[1].used_per;
                                                }
                                                else{
                                                    y = 0;
                                                }
                                            }
                                        };
                                        series1.setData([['已用',y], ['剩余',100 - y]]);
                                    }
                                    catch(e){
                                        console.log(e);
                                    }
                                }, 3000);
                            }
                        }
                    },
                    title: {
                      text: '存储空间',
                      verticalAlign: "bottom",
                      style: {
                        color: '#000',
                        fontFamily: 'Microsoft YaHei',
                        fontSize: 16
                      }
                    },
                    subtitle: {
                      text: ''
                    },
                    xAxis: {
                      type: 'category',
                      gridLineColor: '#FFF',
                      tickColor: '#FFF',
                      labels: {
                        enabled: false,
                        rotation: -45,
                        style: {
                          fontSize: '13px',
                          fontFamily: 'opensans-serif'
                        }
                      }
                    },
                    yAxis: {
                      gridLineColor: '#FFF',
                      min: 0,
                      max: 100,
                      title: {
                        text: ''
                      },
                      labels: {
                        enabled: true
                      }
                    },
                    credits: {
                      enabled: false
                    },
                    exporting: {
                      enabled: false
                    },
                    legend: {
                      enabled: true,
                      backgroundColor: '#FFFFFF',
                      floating: true,
                      align: 'right',
                      layout: 'vertical',
                      verticalAlign: 'top',
                      itemStyle: {
                        color: 'rgb(110,110,110)',
                        fontWeight: '100',
                        fontFamily: "Microsoft YaHei"
                      }
                    },
                    tooltip: {
                      pointFormat: '<b>{point.y:.1f}%</b>',
                      style: {
                        color: '#fff',
                        fontSize: '12px',
                        opacity: 0.8
                      },
                      borderRadius: 0,
                      borderColor: '#000',
                      backgroundColor: '#000'
                    },
                    plotOptions: {
                      pie: {
                        animation: false,
                        shadow: false,
                        borderColor: "rgba(0,0,0,0)",
                        dataLabels: {
                          enabled: false
                        }
                      }
                    },
                    colors: ["rgb(146, 109, 222)", "rgba(146, 109, 222,0.2)"],
                    series: [{
                        name: '存储空间',
                        data: [
                            ['已用',   0],
                            ['剩余',   100]
                        ]
                    }]
                });
            });
        }`);
        
    subitems: () =>
        items = subitems @_temporary(), Location:"", host:"native", \
        health:"normal", raid:"", role:"unused", cap_sector:5860000000, \
        sn: "WD-WCC2E4EYFU91", vendor: "WDC"
        return items
    
    refresh_flow: () =>
        try
            for i in @sd.stats.items[@sd.stats.items.length - 1].storages
                if i.ip is @device.name
                    console.log i.info
                    @plot_flow_in i.info
                    @plot_flow_out i.info
        catch e
            console.log e
            
    refresh: () =>
        try
            for i in @sd.stats.items[@sd.stats.items.length - 1].storages
                if i.ip is @device.name
                    @vm.cpu_load = i.info[i.info.length - 1].cpu
                    @vm.mem_load = i.info[i.info.length - 1].mem
                    @vm.cache_load = i.info[i.info.length - 1].cache_used/i.info[i.info.length - 1].cache_total
                    system = i.info[i.info.length - 1].df[0].used_per
                    cap = i.info[i.info.length - 1].df[1].used_per
                    temp = i.info[i.info.length - 1].temp
                    @sparkline_stats system,temp,cap
        catch e
            console.log e
            
    plot_flow_in: (yaxis, name) =>
        $(document).ready(`function () {
            Highcharts.setOptions({
                global: {
                    useUTC: false
                }
            });
            var chart = Highcharts.chart('flow_stats_in', {
                chart: {
                    type: 'areaspline',
                    //animation:false,
                    animation: Highcharts.svg, // don't animate in old IE
                    marginRight: 10,
                    plotBorderColor:"rgb(255, 255, 255)",
                    plotBorderWidth:1,
                    //backgroundColor:"rgb(250, 250, 250)",
                    events: {
                        load: function () {
                            var series1 = this.series[0];
                            var series2 = this.series[1];
                            setInterval(function () {
                                try{
                                    var type1 = 'write_mb';
                                    var type2 = 'read_mb';
                                    var x = (new Date()).getTime(); // current time
                                    var y1 = 0;
                                    var y2 = 0;
                                    for (var i=0;i< yaxis[yaxis.length - 1].storages.length;i++){
                                        if( yaxis[yaxis.length - 1].storages[i].ip == name){
                                            y1 = yaxis[yaxis.length - 1].storages[i].info[0][type1];
                                            y2 = yaxis[yaxis.length - 1].storages[i].info[0][type2];
                                        }
                                    };
                                    var random = Math.random();
                                    series1.addPoint([x, y1 + random], true, true);
                                    series2.addPoint([x, y2 + random], true, true);
                                }
                                catch(e){
                                    console.log(e);
                                }
                            }, 3000);
                            series2.hide();
                        }
                    }
                },
                title: {
                    text: ''
                },
                xAxis: {
                    tickWidth: 0,
                    labels: {
                        enabled: false
                    },
                    type: 'datetime',
                    tickPixelInterval: 150
                },
                yAxis: {
                    maxPadding: 2,
                    tickAmount: 4,
                    min:-1,
                    title: {
                        text: ''
                    },
                    plotLines: [{
                        value: 0,
                        width: 1,
                        color: '#808080'
                    }]
                },
                tooltip: {
                    formatter: function () {
                        return '<b>' + this.series.name + '</b><br/>' +
                            Highcharts.dateFormat('%Y-%m-%d %H:%M:%S', this.x) + '<br/>' +
                            Highcharts.numberFormat(this.y, 2);
                    },
                    style: {
                        color:'#fff',
                        fontSize:'12px',
                        opacity:0.8
                    },
                    borderRadius:0,
                    borderColor:'#000',
                    backgroundColor:'#000',
                },
                credits: {
                    enabled:false
                },
                legend: {
                    enabled: false
                },
                exporting: {
                    enabled: false
                },
                //colors:["rgba(227,91,90,0.4)","rgba(227,91,243,0.1)"],
                plotOptions: {
                    areaspline: {
                        threshold: null,
                        //animation:false,
                        states: {
                            hover: {
                                lineWidth: 1
                            }
                        },
                        fillOpacity: 0.2,
                        fillColor:"rgba(227,91,90,0.4)",
                        marker: {
                            enabled: false,
                            symbol: 'circle',
                            radius: 5,
                            lineWidth:2,
                            lineColor:"#fff",
                            fillColor:"rgba(255,120,120,0.7)",
                            states: {
                                hover: {
                                    enabled: true,
                                    fillColor:"rgb(227,91,90)"
                                }
                            }
                        },
                        lineWidth: 2,
                        lineColor:"rgb(227,91,90)"
                    }
                },
                series: [{
                    name: '写流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            for (i = -9; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    y: Math.random()
                                });
                            }
                            return data;
                        }
                        catch(e){
                            console.log(e);
                        }
                    }())
                },{
                    name: '读流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            for (i = -9; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    y: Math.random()
                                });
                            }
                            return data;
                        }
                        catch(e){
                            console.log(e);
                        }
                    }())
                }]
            });
            $('#net_write').click(function () {
                var series1 = chart.series[0];
                var series2 = chart.series[1];
                series1.show();
                series2.hide();
            });
            $('#net_read').click(function () {
                var series1 = chart.series[0];
                var series2 = chart.series[1];
                series1.hide();
                series2.show();
            });
        }`);

    plot_flow_out: (yaxis,name) =>
        $(document).ready(`function () {
            Highcharts.setOptions({
                global: {
                    useUTC: false
                }
            });
            var chart = Highcharts.chart('flow_stats_out', {
                chart: {
                    type: 'areaspline',
                    //animation:false,
                    animation: Highcharts.svg, // don't animate in old IE
                    marginRight: 10,
                    plotBorderColor:"rgb(255, 255, 255)",
                    plotBorderWidth:1,
                    //backgroundColor:"rgb(250, 250, 250)",
                    events: {
                        load: function () {
                            var series1 = this.series[0];
                            var series2 = this.series[1];
                            setInterval(function () {
                                try{
                                    var type1 = 'write_vol';
                                    var type2 = 'read_vol';
                                    var x = (new Date()).getTime();// current time
                                    var y1 = 0;
                                    var y2 = 0;
                                    for (var i=0;i< yaxis[yaxis.length - 1].storages.length;i++){
                                        if( yaxis[yaxis.length - 1].storages[i].ip == name){
                                            y1 = yaxis[yaxis.length - 1].storages[i].info[0][type1];
                                            y2 = yaxis[yaxis.length - 1].storages[i].info[0][type2];
                                        }
                                    };
                                    var random = Math.random();
                                    series1.addPoint([x, y1 + random], true, true);
                                    series2.addPoint([x, y2 + random], true, true);
                                }
                                catch(e){
                                    console.log(e);
                                }
                            }, 3000);
                            series2.hide();
                        }
                    }
                },
                title: {
                    text: ''
                },
                xAxis: {
                    tickWidth: 0,
                    labels: {
                        enabled: false
                    },
                    type: 'datetime',
                    tickPixelInterval: 150
                },
                yAxis: {
                    maxPadding: 2,
                    tickAmount: 4,
                    min:-1,
                    title: {
                        text: ''
                    },
                    plotLines: [{
                        value: 0,
                        width: 1,
                        color: '#808080'
                    }]
                },
                tooltip: {
                    formatter: function () {
                        return '<b>' + this.series.name + '</b><br/>' +
                            Highcharts.dateFormat('%Y-%m-%d %H:%M:%S', this.x) + '<br/>' +
                            Highcharts.numberFormat(this.y, 2);
                    },
                    style: {
                        color:'#fff',
                        fontSize:'12px',
                        opacity:0.8
                    },
                    borderRadius:0,
                    borderColor:'#000',
                    backgroundColor:'#000'
                },
                credits: {
                    enabled:false
                },
                legend: {
                    enabled: false
                },
                exporting: {
                    enabled: false
                },
                plotOptions: {
                    areaspline: {
                        threshold: null,
                        //animation:false,
                        states: {
                            hover: {
                                lineWidth: 2
                            }
                        },
                        fillOpacity: 0.2,
                        marker: {
                            enabled: false,
                            symbol: 'circle',
                            radius: 4.5,
                            fillColor:"rgb(143, 208, 253)",
                            states: {
                                hover: {
                                    enabled: true
                                }
                            }
                        },
                        lineWidth: 2
                    }
                },
                colors:["rgb(115, 172, 240)","rgb(115, 172, 240)"],
                series: [{
                    name: '写流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            for (i = -9; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    y: Math.random()
                                });
                            }
                            return data;
                        }
                        catch(e){
                            console.log(e);
                        }
                    }())
                },{
                    name: '读流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            for (i = -9; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    y: Math.random()
                                });
                            }
                            return data;
                        }
                        catch(e){
                            console.log(e);
                        }
                    }())
                }]
            });
            $('#vol_write').click(function () {
                var series1 = chart.series[0];
                var series2 = chart.series[1];
                series1.show();
                series2.hide();
            });
            $('#vol_read').click(function () {
                var series1 = chart.series[0];
                var series2 = chart.series[1];
                series1.hide();
                series2.show();
            });
        }`);
        
    disks:() =>
        try
            tmp = []
            for i in @sd.machinedetails.items
                if i.uuid is @message
                    tmp = i.disks
            for j in tmp
                if j.raid is ''
                    j.raid = '无'
            return tmp
        catch e
            console.log e
    raids:() =>
        try
            for i in @sd.machinedetails.items
                if i.uuid is @message
                    return i.raids
        catch e
            console.log e
    volumes:() =>
        try 
            for i in @sd.machinedetails.items
                if i.uuid is @message
                    return i.volumes
        catch e
            console.log e
        
    filesystems:() =>
        try 
            for i in @sd.machinedetails.items
                if i.uuid is @message
                    return i.filesystems
        catch e
            console.log e
        
    initiators:() =>
        try
            for i in @message.initiators
                i.iface = (portal for portal in i.portals).join ","
                i.map = (volume for volume in i.volumes).join ","
                if i.map is ''
                    i.map = '无'
            return @message.initiators
        catch e
            console.log e
            
    smget: (e) =>
        @vm.smart = e.smartinfo

    smarts: () =>
        try
            smart = ['CurrentPendingSector','LoadCycleCount','OfflineUncorrectable', \
            'PowerCycleCount', 'PowerOffRetractCount', 'PowerOnHours', \
            'RawReadErrorRate', 'ReallocatedSectorCt', 'SeekErrorRate', \
            'SpinRetryCount', 'SpinUpTime', 'StartStopCount', 'UDMACRCErrorCount']
    
            items = subitems @sd.stores.items, Location: "", CurrentPendingSector:"", \
            LoadCycleCount:"", OfflineUncorrectable:"", PowerCycleCount:"", \
            PowerOffRetractCount:"", PowerOnHours: "", RawReadErrorRate: "", \
            ReallocatedSectorCt: "", SeekErrorRate: "", SpinRetryCount: "", \
            SpinUpTime: "", StartStopCount: "", UDMACRCErrorCount: ""
    
            temp = {}
            tem = []
            temps = []
            for i in items
                $.each i, (key, val) ->
                    switch key
                        when 'Location'
                            temp.location = val
                            temp.num = Number(val.split('.')[2])
                        else 
                            tem.push 'name':key,'val':val
                temp.smartinfo = tem
                temps.push temp
                tem = []
                temp = {}
                
            temps.sort(@_compare('num'))
            temps
        
        catch error
            console.log error
            return []

    slots: () =>
        try
            temp = []
            for i in @sd.machinedetails.items
                if i.uuid is @device.uuid
                    if i.disks.length is 0
                        (new MessageModal(lang.centraldisk.no_data)).attach()
                        return
                    else
                        temp = i.disks
                        
            details = @query_list temp
            slot = @get_slots details
            slot
        catch error
            console.log error
        
    _temporary: () =>
        query_disks = (new MachineRest(@sd.host))
        machine_detail = query_disks.machine @device.uuid
        machine_detail.done (data) =>
            if data.detail == null
                @vm.slots = @test()
            else
                details = @query_list data.detail
                slots = @get_slots details
                @vm.slots = slots
            
    query_list: (details) =>
        console.log details
        query = []
        o = {}
        try
            for i in details
                o = location:i.location, uuid:i.id, role:i.role,\
                raid:i.raid, health:i.health, cap_sector:i.cap
                query.push o
            items = subitems query, location:"", host:"native", \
            health:"", raid:"", role:"", cap_sector:5860000000, \
            sn: "WD-WCC2E4EYFU91", vendor: "WDC", type: "enterprise", model: "WD5000AAKX-60U6AA0" 

            return items
        catch error
            return []

    _subitems: () =>
        chain = new Chain()
         
        query_disks = (new MachineRest(@sd.host))
        console.log query_disks
        machine_detail = query_disks.machine @device.uuid
        machine_detail.done (data) =>
            if data.detail is not null
                machines =  @get_slots_b data.detail
                return machines

    get_slots_b: (details) =>
        slotgroups = []
        slotgroup = []
        count = 0

        for i in details
            count += 1
            o = @_get_slots_b i.Location
            o.raid = "normal"
            o.raidcolor = "color0"
            o.role = "unused"
            slotgroup.push o
            if details.length is count or count%4 is 0 
                slotgroups.push slotgroup
                slotgroup = []
        
        return slotgroups

    _get_slots_b: (machine) =>
        regex = /\.(\d{1,2})$/
        return slot:machine.match(regex)[1]
        
            
    get_slots: (temp) =>
        slotgroups = []
        slotgroup = []
        dsus = [{location:"1.1",support_disk_nr:@device.slotnr}]
        dsu_disk_num = 0
        raid_color_map = @_get_raid_color_map(temp)
        for dsu in dsus
            for i in [1..dsu.support_disk_nr]
                o = @_has_disk(i, dsu, dsu_disk_num, temp)
                o.raidcolor = raid_color_map[o.raid]
                o.info = @_get_disk_info(i, dsu, temp)
                slotgroup.push o
                if i%4 is 0
                    slotgroups.push slotgroup
                    slotgroup = []
            dsu_disk_num = dsu_disk_num + dsu.support_disk_nr

        console.log slotgroups
        return slotgroups

    get_raids: () =>
        raids = []
        raid_color_map = @_get_raid_color_map()
        for key, value of raid_color_map
            o = name:key, color:value
            raids.push o
        return raids

    disk_list: (disks) =>
       
        if disks.info == "none"
            return "空盘"
        else
            return @_translate(disks.info)

    _translate: (obj) =>
        status = ''
        health = {'normal':'正常', 'down':'下线', 'failed':'损坏'}
        role = {'data':'数据盘', 'spare':'热备盘', 'unused':'未使用', \
        'kicked':'损坏', 'global_spare':'全局热备盘', 'data&spare':'数据热备盘'}
        type = {'enterprise': '企业盘', 'monitor': '监控盘', 'sas': 'SAS盘'}
        
        $.each obj, (key, val) ->
            #console.log key
            #console.log val
            switch key
                when 'cap_sector'
                    status += '容量: ' + fattr.cap(val)+ '<br/>'
                when 'health'
                    status += '健康: ' + health[val] + '<br/>'
                when 'role'
                    status += '状态: ' + role[val] + '<br/>'
                when 'raid'
                    if val.length == 0
                        val = '无'
                    status += '阵列: ' + val + '<br/>'
                when 'vendor'
                    status += '品牌: ' + val + '<br/>'
                when 'sn'
                    status += '序列号: ' + val + '<br/>'
                when 'model'
                    status += '型号: ' + val + '<br/>'
                when 'type'
                    name = '未知'
                    mod = obj.model.match(/(\S*)-/)[1];
                    $.each disks_type, (j, k) ->
                        if mod in k
                            name = type[j]
                    status += '类型: ' + name + '<br/>'
                    
        status
        
    _get_disk_info: (slotNo, dsu, temp) =>
        for disk in temp
            if disk.location is "#{dsu.location}.#{slotNo}"
                info = health:disk.health, cap_sector:disk.cap_sector, \
                role:disk.role, raid:disk.raid, vendor:disk.vendor, \
                sn:disk.sn, model:disk.model, type:disk.type
                return info
        'none'
        
    _has_disk: (slotNo, dsu, dsu_disk_num,temp) =>
        loc = "#{dsu_disk_num + slotNo}"
        for disk in temp
            if disk.location is "#{dsu.location}.#{slotNo}"
                rdname = if disk.raid is ""\
                    then "noraid"\
                    else disk.raid
                rdrole = if disk.health is "down"\
                    then "down"\
                    else disk.role
                o = slot: loc, role:rdrole, raid:rdname, raidcolor: ""
                return o
        o = slot: loc, role:"nodisk", raid:"noraid", raidcolor: ""
        return o

    _get_raid_color_map: (temp) =>
        map = {}
        raids = []
        i = 1
        has_global_spare = false
        for disk in temp
            if disk.role is "global_spare"
                has_global_spare = true
                continue
            rdname = if disk.raid is ""\
                then "noraid"\
                else disk.raid
            if rdname not in raids
                raids.push rdname
        for raid in raids
            map[raid] = "color#{i}"
            i = i + 1
        map["noraid"] = "color0"
        if has_global_spare is true
            map["global_spare"] = "color5"
        return map

    test: () =>
        return [[{raid: "normal",raidcolor: "color0",role: "unused",slot:"1"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"2"},\
        {raid: "normal",raidcolor: "color0",role: "unused",slot:"3"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"4"}],\
        [{raid: "normal",raidcolor: "color0",role: "unused",slot:"5"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"6"},\
        {raid: "normal",raidcolor: "color0",role: "unused",slot:"7"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"8"}],\
        [{raid: "normal",raidcolor: "color0",role: "unused",slot:"9"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"10"},\
        {raid: "normal",raidcolor: "color0",role: "unused",slot:"11"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"12"}],\
        [{raid: "normal",raidcolor: "color0",role: "unused",slot:"13"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"14"},\
        {raid: "normal",raidcolor: "color0",role: "unused",slot:"15"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"16"}]]

    _compare: (propertyname) =>
        (obj1, obj2) =>
            value1 = obj1[propertyname]
            value2 = obj2[propertyname]
            if value1 < value2
                return -1
            else if value1 > value2
                return 1
            else 
                return 0    

class CentralServerDetailPage extends Page
    constructor: (@sd, @page, @device, @switch_to_page, @message) ->
        super "centralserverdetailpage-", "html/centralserverdetailpage.html"
        
        $(@sd.stats).on "updated", (e, source) =>
            if @has_rendered
                latest = source.items[source.items.length - 1]
                for i in latest.exports
                    if i.ip is @device.name
                        @vm.cpu_load = parseInt i.info[0].cpu
                        @vm.mem_load = parseInt i.info[0].mem
                        @vm.cache_load = parseInt i.info[0].df[0].used_per
                        #@sparkline_stats system,temp,cap
                        #@refresh_flow()
                        
        $(@sd.journals).on "updated", (e, source) =>
            @vm.journal = @subitems_log()
            
    define_vm: (vm) =>
        vm.lang = lang.centraldisk
        vm.switch_to_page = @switch_to_page
        vm.cpu_load = 0
        vm.cache_load = 0
        vm.flow_type = "fwrite_mb"
        vm.mem_load = 0
        vm.tabletitle = @device.name
        vm.$watch "cpu_load", (nval, oval) =>
            $("#cpu-load").data("easyPieChart").update?(nval) if @has_rendered
            return
        vm.$watch "cache_load", (nval, oval) =>
            $("#cache-load").data("easyPieChart").update?(nval) if @has_rendered
            return
        vm.$watch "mem_load", (nval, oval) =>
            $("#mem-load").data("easyPieChart").update?(nval) if @has_rendered
            return
        vm.fattr_journal_status = fattr.journal_status
        vm.journal = @subitems_log()
        vm.journal_info = @subitems_info()
        vm.journal_warning = @subitems_warning()
        vm.journal_critical = @subitems_critical()
        vm.rendered = @rendered
        vm.fattr_monitor_status = fattr.monitor_status
        vm.fattr_view_status_fixed = fattr.view_status_fixed
        
    rendered: () =>
        super()
        #@refresh_pie @sd
        opt1 = animate: 1000, size: 100, lineWidth: 5, lineCap: "butt", barColor: "rgb(87, 199, 212)",trackColor: 'rgba(87, 199, 212,0.1)',scaleColor: false
        opt2 = animate: 1000, size: 100, lineWidth: 5, lineCap: "butt", barColor: "rgb(98, 168, 234)",trackColor: 'rgba(98, 168, 234,0.1)',scaleColor: false
        opt3 = animate: 1000, size: 100, lineWidth: 5, lineCap: "butt", barColor: "rgb(146, 109, 222)",trackColor: 'rgba(146, 109, 222,0.1)',scaleColor: false
        
        $("#cpu-load").easyPieChart opt1
        $("#cpu-load").data("easyPieChart").update? @vm.cpu_load
        $("#cache-load").easyPieChart opt2
        $("#cache-load").data("easyPieChart").update? @vm.cache_load
        $("#mem-load").easyPieChart opt3
        $("#mem-load").data("easyPieChart").update? @vm.mem_load
        
        @data_table1 = $("#log-table1").dataTable dtable_opt(retrieve: true, bSort: false,scrollX: true)
        @data_table2 = $("#log-table2").dataTable dtable_opt(retrieve: true, bSort: false,scrollX: true)
        @data_table3 = $("#log-table3").dataTable dtable_opt(retrieve: true, bSort: false,scrollX: true)
        @data_table4= $("#log-table4").dataTable dtable_opt(retrieve: true, bSort: false,scrollX: true)
        $(".dataTables_filter input").addClass "m-wrap small"
        $(".dataTables_length select").addClass "m-wrap small"
        
        $scroller1 = $("#journals-scroller-1")
        $scroller2 = $("#journals-scroller-2")
        $scroller3 = $("#journals-scroller-3")
        $scroller4 = $("#journals-scroller-4")
        
        $scroller1.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller1.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
        $scroller2.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller2.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
        $scroller3.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller3.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
        $scroller4.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller4.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
            
        #@refresh_flow()
        #@sparkline_stats 10,50,90
        try
            @plot_flow_in @sd.stats.items,@device.name
        catch e
            console.log e
            
    subitems_log: () =>
        try
            arrays = []
            for i in @sd.machinedetails.items
                if i.uuid is @message
                   arrays = i.journals
            for t in arrays
                t.created = t.created.replace("-","/").replace("-","/").replace("T","-").replace("+08:00","")
            arrays.reverse()
        catch error
            return []
        
    subitems_info: () =>
        info = []
        ((info.push i) for i in @subitems_log() when i.level is 'info')
        info
            
    subitems_warning: () =>
        info = []
        ((info.push i) for i in @subitems_log() when i.level is 'warning')
        info
            
    subitems_critical: () =>
        info = []
        ((info.push i) for i in @subitems_log() when i.level is 'critical')
        info
        
    sparkline_stats: (system,temp,cap) =>
        arm =
            chart: 
                type: 'column'
            title: 
                text: ''
                verticalAlign: "bottom"
                style: 
                    color: '#000'
                    fontFamily: 'Microsoft YaHei'
                    fontSize:16
            subtitle: 
                text: ''
            xAxis:
                type: 'category'
                gridLineColor: '#FFF'
                tickColor: '#FFF'
                labels: 
                    enabled: false
                    rotation: -45
                    style: 
                        fontSize: '13px'
                        fontFamily: 'Verdana, sans-serif'
            yAxis: 
                gridLineColor: '#FFF'
                min: 0
                title: 
                    text: ''
                labels: 
                    enabled: false
            credits: 
                enabled:false
            exporting: 
                enabled: false
            legend: 
                enabled: false
            tooltip: 
                pointFormat: '<b>{point.y:.1f}</b>'
            plotOptions: 
                column: 
                    animation:false,
                    pointPadding: 0.01,
                    groupPadding: 0.01,
                    borderWidth: 0.01,
                    shadow: false,
                    pointWidth: 7
            series: [{
                name: 'Population'
            }]

        $('#sparkline_bar1').highcharts(Highcharts.merge(arm,
            title: 
                text: '处理器'
            plotOptions: 
                column: 
                    color: '#35aa47'
            series: [{
                data: [
                    ['Lima', 8.9],
                    ['Karachi', 14.0],
                    ['Jakarta', 10.0],
                    ['Kinshasa', 9.3],
                    ['Tianjin', 9.3],
                    ['Tokyo', 9.0],
                    ['Cairo', 8.9],
                    ['Shanghai', 23.7],
                    ['Lagos', 16.1],
                    ['Instanbul', 14.2],
                    ['Dhaka', 8.9],
                    ['Mexico City', 8.9]
                ]
            }]
        ))
        $('#sparkline_bar2').highcharts(Highcharts.merge(arm, 
            title: 
                text: '系统空间'
            plotOptions: 
                column: 
                    color: '#ffb848'
            series: [{
                data: [
                    ['Shanghai', 23.7],
                    ['Lagos', 16.1],
                    ['Instanbul', 14.2],
                    ['Dhaka', 8.9],
                    ['Mexico City', 8.9],
                    ['Lima', 8.9],
                    ['Karachi', 14.0],
                    ['Jakarta', 10.0],
                    ['Kinshasa', 9.3],
                    ['Tianjin', 9.3],
                    ['Tokyo', 9.0],
                    ['Cairo', 8.9]
                ]
            }]
        ))
        
        $('#sparkline_bar3').highcharts(Highcharts.merge(arm, 
            title: 
                text: '内存'
            plotOptions: 
                column: 
                    color: '#e7505a'
            series: [{
                data: [
                    ['Lima', 8.9],
                    ['Karachi', 14.0],
                    ['Jakarta', 10.0],
                    ['Tokyo', 9.0],
                    ['Cairo', 8.9],
                    ['Shanghai', 23.7],
                    ['Lagos', 16.1],
                    ['Instanbul', 14.2],
                    ['Kinshasa', 9.3],
                    ['Tianjin', 9.3],
                    ['Dhaka', 8.9],
                    ['Mexico City', 8.9]
                ]
            }]
        ))
        
    subitems: () =>
        return []
        
    refresh_flow: () =>
        try
            for i in @sd.stats.items[@sd.stats.items.length - 1].exports
                if i.ip is @device.name
                    @plot_flow_in i.info
                    @plot_flow_out i.info
        catch e
            console.log e
            
    refresh: () =>
        try
            for i in @sd.stats.items[@sd.stats.items.length - 1].exports
                if i.ip is @device.name
                    @vm.cpu_load = i.info[i.info.length - 1].cpu
                    @vm.mem_load = i.info[i.info.length - 1].mem
                    @vm.cache_load = i.info[i.info.length - 1].df[0].used_per
        catch e
            console.log e
        
    refresh_pie: (sd) =>
        $(`function () {
            var gaugeOptions = {
                chart: {
                    type: 'gauge',
                    plotBackgroundColor: null,
                    plotBackgroundImage: null,
                    plotBorderWidth: 0,
                    plotShadow: false
                },
                exporting: {
                    enabled: false
                },
                credits: {
                    enabled:false
                },
                title: {
                    style:{
                        fontWeight:'bold',
                        fontSize:19,
                        color:'#000'
                    }
                },
                pane: {
                    startAngle: -150,
                    endAngle: 150,
                    background: [{
                        backgroundColor: {
                            linearGradient: { x1: 0, y1: 0, x2: 0, y2: 1 },
                            stops: [
                                [0, '#FFF'],
                                [1, '#333']
                            ]
                        },
                        borderWidth: 0,
                        outerRadius: '109%'
                    }, {
                        backgroundColor: {
                            linearGradient: { x1: 0, y1: 0, x2: 0, y2: 1 },
                            stops: [
                                [0, '#333'],
                                [1, '#FFF']
                            ]
                        },
                        borderWidth: 1,
                        outerRadius: '107%'
                    }, {
                        // default background
                    }, {
                        backgroundColor: '#DDD',
                        borderWidth: 0,
                        outerRadius: '105%',
                        innerRadius: '103%'
                    }]
                },
                // the value axis
                yAxis: {
                    min: 0,
                    max: 100,
                    minorTickInterval: 'auto',
                    minorTickWidth: 1,
                    minorTickLength: 10,
                    minorTickPosition: 'inside',
                    minorTickColor: '#666',
                    tickPixelInterval: 30,
                    tickWidth: 2,
                    tickPosition: 'inside',
                    tickLength: 10,
                    tickColor: '#666',
                    labels: {
                        step: 2,
                        rotation: 'auto'
                    },
                    title: {
                        text: '%'
                    },
                    plotBands: [{
                        from: 0,
                        to: 120,
                        color: '#55BF3B' // green
                    }, {
                        from: 120,
                        to: 160,
                        color: '#DDDF0D' // yellow
                    }, {
                        from: 160,
                        to: 200,
                        color: '#DF5353' // red
                    }]
                }
            };
            $('#container_cpu').highcharts(Highcharts.merge(gaugeOptions, {
                    title: {
                        text:'处理器'
                    },
                    series: [{
                        name: '处理器',
                        data: [0],
                        tooltip: {
                            valueSuffix: '%'
                        }
                    }]
                }));
                
            $('#container_cache').highcharts(Highcharts.merge(gaugeOptions, {
                    title: {
                        text:'缓存'
                    },
                    series: [{
                        name: '缓存',
                        data: [0],
                        tooltip: {
                            valueSuffix: '%'
                        }
                    }]
                }));
                
            $('#container_mem').highcharts(Highcharts.merge(gaugeOptions, {
                    title: {
                        text:'内存'
                    },
                    series: [{
                        name: '内存',
                        data: [0],
                        tooltip: {
                            valueSuffix: '%'
                        }
                    }]
                }));
            setInterval(function () {
                // cpu
                var latest = sd.stats.items[sd.stats.items.length-1];
                var cpu_load  = parseInt(latest.cpu);
                var cache_load  = parseInt(latest.cache);
                var mem_load = parseInt(latest.mem);
                
                var chart = $('#container_cpu').highcharts(),
                    point,
                    newVal,
                    inc;
                if (chart) {
                    point = chart.series[0].points[0];
                    point.update(cpu_load);
                }
                
                // cache
                chart = $('#container_cache').highcharts();
                if (chart) {
                    point = chart.series[0].points[0];
                    point.update(cache_load);
                }
                
                //mem
                chart = $('#container_mem').highcharts();
                if (chart) {
                    point = chart.series[0].points[0];
                    point.update(mem_load);
                }
            }, 2000);
        }`);
           
    plot_flow_in: (yaxis, name) =>
        $(document).ready(`function () {
            Highcharts.setOptions({
                global: {
                    useUTC: false
                }
            });
            var chart = Highcharts.chart('flow_stats_in', {
                chart: {
                    type: 'areaspline',
                    //animation:false,
                    animation: Highcharts.svg, // don't animate in old IE
                    marginRight: 10,
                    plotBorderColor:"rgb(255, 255, 255)",
                    plotBorderWidth:1,
                    //backgroundColor:"rgb(250, 250, 250)",
                    events: {
                        load: function () {
                            var series1 = this.series[0];
                            var series2 = this.series[1];
                            setInterval(function () {
                                try{
                                    var type1 = 'write_mb';
                                    var type2 = 'read_mb';
                                    var x = (new Date()).getTime(); // current time
                                    var y1 = 0;
                                    var y2 = 0;
                                    for (var i=0;i< yaxis[yaxis.length - 1].exports.length;i++){
                                        if( yaxis[yaxis.length - 1].exports[i].ip == name){
                                            y1 = yaxis[yaxis.length - 1].exports[i].info[0][type1];
                                            y2 = yaxis[yaxis.length - 1].exports[i].info[0][type2];
                                        }
                                    };
                                    var random = Math.random();
                                    series1.addPoint([x, y1 + random], true, true);
                                    series2.addPoint([x, y2 + random], true, true);
                                }
                                catch(e){
                                    console.log(e);
                                }
                            }, 3000);
                            series2.hide();
                        }
                    }
                },
                title: {
                    text: ''
                },
                xAxis: {
                    tickWidth: 0,
                    labels: {
                        enabled: false
                    },
                    type: 'datetime',
                    tickPixelInterval: 150
                },
                yAxis: {
                    maxPadding: 2,
                    tickAmount: 4,
                    min:-1,
                    title: {
                        text: ''
                    },
                    plotLines: [{
                        value: 0,
                        width: 1,
                        color: '#808080'
                    }]
                },
                tooltip: {
                    formatter: function () {
                        return '<b>' + this.series.name + '</b><br/>' +
                            Highcharts.dateFormat('%Y-%m-%d %H:%M:%S', this.x) + '<br/>' +
                            Highcharts.numberFormat(this.y, 2);
                    },
                    style: {
                        color:'#fff',
                        fontSize:'12px',
                        opacity:0.8
                    },
                    borderRadius:0,
                    borderColor:'#000',
                    backgroundColor:'#000',
                },
                credits: {
                    enabled:false
                },
                legend: {
                    enabled: false
                },
                exporting: {
                    enabled: false
                },
                //colors:["rgba(227,91,90,0.4)","rgba(227,91,243,0.1)"],
                plotOptions: {
                    areaspline: {
                        threshold: null,
                        //animation:false,
                        states: {
                            hover: {
                                lineWidth: 1
                            }
                        },
                        fillOpacity: 0.2,
                        fillColor:"rgba(227,91,90,0.4)",
                        marker: {
                            enabled: false,
                            symbol: 'circle',
                            radius: 5,
                            lineWidth:2,
                            lineColor:"#fff",
                            fillColor:"rgba(255,120,120,0.7)",
                            states: {
                                hover: {
                                    enabled: true,
                                    fillColor:"rgb(227,91,90)"
                                }
                            }
                        },
                        lineWidth: 2,
                        lineColor:"rgb(227,91,90)"
                    }
                },
                series: [{
                    name: '写流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            for (i = -9; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    y: Math.random()
                                });
                            }
                            return data;
                        }
                        catch(e){
                            console.log(e);
                        }
                    }())
                },{
                    name: '读流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            for (i = -9; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    y: Math.random()
                                });
                            }
                            return data;
                        }
                        catch(e){
                            console.log(e);
                        }
                    }())
                }]
            });
            $('#net_write').click(function () {
                var series1 = chart.series[0];
                var series2 = chart.series[1];
                series1.show();
                series2.hide();
            });
            $('#net_read').click(function () {
                var series1 = chart.series[0];
                var series2 = chart.series[1];
                series1.hide();
                series2.show();
            });
        }`);

    plot_flow_out: (yaxis) =>
        $(document).ready(`function () {
            Highcharts.setOptions({
                global: {
                    useUTC: false
                }
            });
            var chart = Highcharts.chart('flow_stats_out', {
                chart: {
                    type: 'areaspline',
                    //animation:false,
                    animation: Highcharts.svg, // don't animate in old IE
                    marginRight: 10,
                    plotBorderColor:"rgb(255, 255, 255)",
                    plotBorderWidth:1,
                    //backgroundColor:"rgb(250, 250, 250)",
                    events: {
                        load: function () {
                            var series1 = this.series[0];
                            var series2 = this.series[1];
                            setInterval(function () {
                                try{
                                    var type1 = 'write_vol';
                                    var type2 = 'read_vol';
                                    var random = Math.random();
                                    var x = (new Date()).getTime(), // current time
                                        y1 = yaxis[yaxis.length - 1][type1];
                                        y2 = yaxis[yaxis.length - 1][type2];
                                    series1.addPoint([x, y1 + random], true, true);
                                    series2.addPoint([x, y2 + random], true, true);
                                }
                                catch(e){
                                    console.log(e);
                                }
                            }, 3000);
                            series2.hide();
                        }
                    }
                },
                title: {
                    text: ''
                },
                xAxis: {
                    tickWidth: 0,
                    labels: {
                        enabled: false
                    },
                    type: 'datetime',
                    tickPixelInterval: 150
                },
                yAxis: {
                    maxPadding: 2,
                    tickAmount: 4,
                    min:-1,
                    title: {
                        text: ''
                    },
                    plotLines: [{
                        value: 0,
                        width: 1,
                        color: '#808080'
                    }]
                },
                tooltip: {
                    formatter: function () {
                        return '<b>' + this.series.name + '</b><br/>' +
                            Highcharts.dateFormat('%Y-%m-%d %H:%M:%S', this.x) + '<br/>' +
                            Highcharts.numberFormat(this.y, 2);
                    },
                    style: {
                        color:'#fff',
                        fontSize:'12px',
                        opacity:0.8
                    },
                    borderRadius:0,
                    borderColor:'#000',
                    backgroundColor:'#000'
                },
                credits: {
                    enabled:false
                },
                legend: {
                    enabled: false
                },
                exporting: {
                    enabled: false
                },
                plotOptions: {
                    areaspline: {
                        threshold: null,
                        //animation:false,
                        states: {
                            hover: {
                                lineWidth: 2
                            }
                        },
                        fillOpacity: 0.2,
                        marker: {
                            enabled: false,
                            symbol: 'circle',
                            radius: 4.5,
                            fillColor:"rgb(143, 208, 253)",
                            states: {
                                hover: {
                                    enabled: true
                                }
                            }
                        },
                        lineWidth: 2
                    }
                },
                colors:["rgb(115, 172, 240)","rgb(115, 172, 240)"],
                series: [{
                    name: '写流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            for (i = -9; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    y: Math.random()
                                });
                            }
                            return data;
                        }
                        catch(e){
                            console.log(e);
                        }
                    }())
                },{
                    name: '读流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            for (i = -9; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    y: Math.random()
                                });
                            }
                            return data;
                        }
                        catch(e){
                            console.log(e);
                        }
                    }())
                }]
            });
            $('#vol_write').click(function () {
                var series1 = chart.series[0];
                var series2 = chart.series[1];
                series1.show();
                series2.hide();
            });
            $('#vol_read').click(function () {
                var series1 = chart.series[0];
                var series2 = chart.series[1];
                series1.hide();
                series2.show();
            });
        }`);
        
    
##################################################################

class CentralServerlistPage extends DetailTablePage
    constructor: (@sd) ->
        super "centralpage-server-list", "html/centralserverlistpage.html"
        $(@sd.clouds).on "updated", (e, source) =>
            @vm.devices = @subitems()
            
        table_update_listener @sd.clouds, "#server-table", =>
            @vm.devices = @subitems() if not @has_frozen

    define_vm: (vm) =>
        vm.devices = @subitems()
        vm.lang = lang.central_server_list
        vm.create_mysql = @create_mysql
        vm.check = @check
        vm.unset = @unset
        vm.rendered = @rendered
        vm.fattr_server_status = fattr.server_status
        vm.fattr_server_health = fattr.server_health
        vm.all_checked = false
        vm.delete_record = @delete_record
        vm.detail = @detail
        vm.expand = @expand
        vm.start = @start
        vm.$watch "all_checked", =>
            for r in vm.devices
                r.checked = vm.all_checked
                
    rendered: () =>
        super()
        $('.tooltips').tooltip()
        @vm.devices = @subitems()
        @data_table = $("#server-table").dataTable dtable_opt(retrieve: true)
        $(".dataTables_filter input").addClass "m-wrap small"
        $(".dataTables_length select").addClass "m-wrap small"
        
    subitems: () =>
        arrays = subitems @sd.clouds.items,id:"",uuid:"", session:"", ip:"", created:"", \
                checked:false, status:"", version:"", devtype:"", size:"",detail_closed:true,export:""
        sub = []
        for i in arrays
            if i.devtype is 'export'
                i.name = '服务器'
                i.id = i.uuid
                sub.push i
        sub
            
    detail_html: (server) =>
        html = avalon_templ server.id, "html/server_detail_row.html"
        for i in @sd.clouds.items
            if i.uuid is server.id
                o = i
        vm = avalon.define server.id, (vm) =>
            vm.stores = subitems @sd.server_stores(o),ip:"",node:"",location:""
            vm.lang = lang.central_server_list
        return [html, vm]
            
    delete_record:() =>
        deleted = ($.extend({},r.$model) for r in @vm.devices when r.checked)
        if deleted.length isnt 0   
            (new CentralRecordDeleteModal(@sd, this, deleted)).attach()
        else
            (new MessageModal(@vm.lang.delete_error)).attach()
            
    create_mysql: () =>
        (new CentralCreateServerModal(@sd, this)).attach()

    expand: (ip) =>
        (new CentralExpandModal(@sd, this, ip)).attach()
        
    unset:(name, ip) =>
        (new ConfirmModal @vm.lang.stop, =>
            @frozen()
            chain = new Chain
            chain.chain =>
                (new MachineRest @sd.host).rozostop "export",ip
            chain.chain @sd.update("all")
            show_chain_progress(chain).done =>
                (new MessageModal (@vm.lang.stop_success)).attach()
                @attach()
        ).attach()
        
    start:(ip) =>
        (new CentralStartModal(@sd, this, ip)).attach()
        
    check: (ip, name) =>
        tmp = ['mysql','mongo','gateway','fileserver','web']
        if name in tmp 
            (new ConfirmModal lang.central_mysql.check, =>
                @frozen()
                chain = new Chain
                chain.chain =>
                    (new MachineRest @sd.host).check ip,name
                chain.chain @sd.update("all")
                show_chain_progress(chain).done =>
                    (new MessageModal (lang.central_mysql.check_success)).attach()
                    @attach()
            ).attach()
        else
            (new MessageModal (lang.central_mysql.check_error)).attach()
            
class CentralStorelistPage extends DetailTablePage
    constructor: (@sd) ->
        super "centralpage-store-list", "html/centralstorelistpage.html"
        $(@sd.clouds).on "updated", (e, source) =>
            @vm.devices = @subitems()
            
        table_update_listener @sd.clouds, "#store-table", =>
            @vm.devices = @subitems() if not @has_frozen
            
    define_vm: (vm) =>
        vm.devices = @subitems() 
        vm.lang = lang.central_store_list
        vm.create_mysql = @create_mysql
        vm.check = @check
        vm.unset = @unset
        vm.pre = @pre
        vm.mount = @mount
        vm.rendered = @rendered
        vm.fattr_server_status = fattr.server_status
        vm.fattr_server_health = fattr.server_health
        vm.all_checked = false
        vm.$watch "all_checked", =>
            for r in vm.devices
                r.checked = vm.all_checked
        vm.delete_record = @delete_record
        vm.detail = @detail
        vm.expand = @expand
        
    rendered: () =>
        super()
        $('.tooltips').tooltip()
        @vm.devices = @subitems()
        @data_table = $("#store-table").dataTable dtable_opt(retrieve: true)
        $(".dataTables_filter input").addClass "m-wrap small"
        $(".dataTables_length select").addClass "m-wrap small"
        
    subitems: () =>
        arrays = subitems @sd.clouds.items,id:"",uuid:"", session:"", ip:"", created:"", \
                checked:false, status:"", version:"", devtype:"", size:"",detail_closed:true,export:""
        sub = []
        for i in arrays
            if i.devtype is 'storage'
                i.name = '存储'
                i.id = i.uuid
                if i.export is ""
                    i.export = '无'
                sub.push i
        sub
            
    detail_html: (store) =>
        html = avalon_templ store.id, "html/store_detail_row.html"
        for i in @sd.clouds.items
            if i.uuid is store.id
                o = i
        vm = avalon.define store.id, (vm) =>
            vm.servers = subitems @sd.store_servers(o),ip:""
            vm.lang = lang.central_store_list
        return [html, vm]
        
    delete_record:() =>
        deleted = ($.extend({},r.$model) for r in @vm.devices when r.checked)
        if deleted.length isnt 0   
            (new CentralRecordDeleteModal(@sd, this, deleted)).attach()
        else
            (new MessageModal(@vm.lang.delete_error)).attach()
    create_mysql: () =>
        (new CentralCreateStoreModal(@sd, this)).attach()
    
    expand: (ip) =>
        (new CentralExpandModal(@sd, this, ip)).attach()
    
    mount: (ip,name) =>
        (new ConfirmModal @vm.lang.mount, =>
            @frozen()
            chain = new Chain
            chain.chain =>
                (new MachineRest @sd.host).rozoset name,ip,""
            chain.chain @sd.update("all")
            show_chain_progress(chain).done =>
                (new MessageModal (@vm.lang.mount_success)).attach()
                @attach()
        ).attach()
        
    pre: () =>
        (new CentralPreModal(@sd, this)).attach()
    
    unset:(name, ip) =>
        (new ConfirmModal @vm.lang.stop, =>
            @frozen()
            chain = new Chain
            chain.chain =>
                (new MachineRest @sd.host).rozostop "storage",ip
            chain.chain @sd.update("all")
            show_chain_progress(chain).done =>
                (new MessageModal (@vm.lang.stop_success)).attach()
                @attach()
        ).attach()
        
    check: (ip, name) =>
        tmp = ['mysql','mongo','gateway','fileserver','web']
        if name in tmp 
            (new ConfirmModal lang.central_mysql.check, =>
                @frozen()
                chain = new Chain
                chain.chain =>
                    (new MachineRest @sd.host).check ip,name
                chain.chain @sd.update("all")
                show_chain_progress(chain).done =>
                    (new MessageModal (lang.central_mysql.check_success)).attach()
                    @attach()
            ).attach()
        else
            (new MessageModal (lang.central_mysql.check_error)).attach()
            
class CentralClientlistPage extends Page
    constructor: (@sd) ->
        super "centralpage-client-list", "html/centralclientlistpage.html"
        $(@sd.clouds).on "updated", (e, source) =>
            @vm.devices = @subitems()
        table_update_listener @sd.clouds, "#client-table", =>
            @vm.devices = @subitems() if not @has_frozen
            
    define_vm: (vm) =>
        vm.devices = @subitems()
        vm.lang = lang.central_client_list
        vm.create_mysql = @create_mysql
        vm.check = @check
        vm.unset = @unset
        vm.start = @start
        vm.pre = @pre
        vm.rendered = @rendered
        vm.fattr_server_status = fattr.server_status
        vm.fattr_server_health = fattr.server_health
        vm.all_checked = false
        vm.$watch "all_checked", =>
            for r in vm.devices
                r.checked = vm.all_checked
        vm.delete_record = @delete_record

    rendered: () =>
        super()
        $('.tooltips').tooltip()
        @vm.devices = @subitems() if not @has_frozen
        @data_table = $("#client-table").dataTable dtable_opt(retrieve: true)
        $(".dataTables_filter input").addClass "m-wrap small"
        $(".dataTables_length select").addClass "m-wrap small"
        
    subitems: () =>
        arrays = subitems @sd.clouds.items,id:"",uuid:"", session:"", ip:"", created:"", \
                checked:false, status:"", version:"", devtype:"", size:"",detail_closed:true,export:""
        sub = []
        for i in arrays
            if i.devtype is 'client'
                i.id = i.uuid
                i.name = '客户端'
                sub.push i
        sub
            
    delete_record:() =>
        deleted = ($.extend({},r.$model) for r in @vm.devices when r.checked)
        if deleted.length isnt 0   
            (new CentralRecordDeleteModal(@sd, this, deleted)).attach()
        else
            (new MessageModal(@vm.lang.delete_error)).attach()
    create_mysql: () =>
        (new CentralCreateClientModal(@sd, this)).attach()
        
    start: (ip) =>
        (new ConfirmModal @vm.lang.start, =>
            @frozen()
            chain = new Chain
            chain.chain =>
                (new MachineRest @sd.host).client ip
            chain.chain @sd.update("all")
            show_chain_progress(chain).done =>
                (new MessageModal (@vm.lang.start_success)).attach()
                @attach()
        ).attach()
        
    pre: () =>
        (new CentralPreModal(@sd, this)).attach()
    
    unset:(name, ip) =>
        (new ConfirmModal @vm.lang.stop, =>
            @frozen()
            chain = new Chain
            chain.chain =>
                (new MachineRest @sd.host).rozostop 'client',ip
            chain.chain @sd.update("all")
            show_chain_progress(chain).done =>
                (new MessageModal (@vm.lang.stop_success)).attach()
                @attach()
        ).attach()
        
    check: (ip, name) =>
        tmp = ['mysql','mongo','gateway','fileserver','web']
        if name in tmp 
            (new ConfirmModal lang.central_mysql.check, =>
                @frozen()
                chain = new Chain
                chain.chain =>
                    (new MachineRest @sd.host).check ip,name
                chain.chain @sd.update("all")
                show_chain_progress(chain).done =>
                    (new MessageModal (lang.central_mysql.check_success)).attach()
                    @attach()
            ).attach()
        else
            (new MessageModal (lang.central_mysql.check_error)).attach()
            
class CentralWarningPage extends DetailTablePage
    constructor: (@sd) ->
        super "maintainpage-", "html/centralwarning.html"
        @settings = new SettingsManager
    define_vm: (vm) =>
     
        vm.lang = lang.central_warning
        vm.diagnosis_url = "http://#{@sd.host}/api/diagnosis/all"
        vm.devices = @subitems()
        vm.emails = @subitems_email()
        vm.add = @add
        vm.change_value = @change_value
        vm.removes = @removes
        vm.change_email = @change_email
        vm.all_checked = false
        vm.$watch "all_checked", =>
            for r in vm.emails
                r.checked = vm.all_checked
    rendered: () =>
        super()
        @vm.devices = @subitems()
        @vm.emails = @subitems_email()
            
    subitems_email: () =>
        tmp = []
        for i in @sd.emails.items
            i.checked = false
            tmp.push i
        tmp
        
    subitems: () =>
        tmp = []
        for i in @sd.warnings.items
            i.bad = i.warning
            if i.type is "cpu"
                i.chinese_type = "处理器"
            if i.type is "diskcap"
                i.chinese_type = "磁盘容量"
            if i.type is "cache"
                i.chinese_type = "缓存"
            if i.type is "mem"
                i.chinese_type = "内存"
            tmp.push i
        tmp
        
    add: () =>
        (new CentralAddEmailModal(@sd, this)).attach()
        
    removes: () =>
        deleted = ($.extend({},r.$model) for r in @vm.emails when r.checked)
        if deleted.length isnt 0   
            (new CentralEmailDeleteModal(@sd, this, deleted)).attach()
        else
            (new MessageModal(@vm.lang.delete_error)).attach()
            
    change_value: (value_type) =>
        (new CentralChangeValueModal(@sd, this, value_type)).attach()
        
    change_email: (address,level,ttl) =>
        (new CentralChangeEmailModal(@sd, this, address,level,ttl)).attach()


###################################################################################
class FaceQuickProPage extends DetailTablePage
    constructor: (@sd,@switch_to_page) ->
        super "facequickpropage-", "html/facequickpropage.html"
        @dataurl = ""
        @personal_id = ""
        @person_msg = ""
        @sayCheese = ""
        @ip_camera_status = false

        @x1 = ""
        @x2 = ""
        @y1 = ""
        @y2 = ""

        @mode = "usb"
        @source_cam = 'usb摄像头'

        $(@sd).on "compareresult", (e, result) =>
            if result.name is "compareResult"
                #@show_stamp(result.confidence)
                @show_stamp_new(result.confidence)

    define_vm: (vm) =>
     
        vm.lang = lang.facepage
        vm.get_card = @get_card
        vm.compare = @compare
        vm.personName = "未对比"
        vm.sex = "未对比"
        vm.birthday = "未对比"
        vm.nation = "未对比"
        vm.personId = "未对比"
        vm.address = "未对比"
        vm.startDate = "未对比"
        vm.endDate = "未对比"
        vm.department = "未对比"
        vm.imgPath = "未对比"

        vm.show_card_result = false
        vm.show_canvas = false
        vm_show_compare = false
        vm.show_loading = false
        vm.show_cam = true
        vm.checked = false
        vm.upload_pic = @upload_pic

        vm.show_upload_canvas = false
        vm.compare_result = ""
        vm.show_results = true
        vm.next_action = "读卡"
        vm.camera_error = true
        vm.retry_camera = @retry_camera
        vm.retry_cameras = @retry_cameras
        vm.show_cut = false
        vm.switch_to_page = @switch_to_page

        vm.status = "未对比"
        vm.result = "未对比"
        vm.com = "0%"

        vm.show_img = true
        vm.show_spin = false
        vm.rendered = @rendered
        vm.show_retry = false
        vm.remove_all = @remove_all
        vm.fattr_compare_status = fattr.compare_status
        vm.show_tracking = false
        vm.amount_compare = 0
        vm.show_all = true
        vm.options_cam = [
          { key: "usb摄像头", value: "usb" }
          { key: "ip摄像头", value: "ip" }
        ]
        vm.change_cam = @change_cam
        vm.show_ip_cam = false
        vm.change_cam_modal = @change_cam_modal
        vm.source_cam = @source_cam

    rendered: () =>
        super()
        new WOW().init();
        $('.hastip-facequickpro').poshytip(
            className: 'tip-twitter'
            showTimeout: 0
            alignTo: 'target'
            alignX: 'center'
            offsetY: 5
        )
        $scroller = $("#journals-scroller-1")
        $scroller.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
        
        #@face_tracking()
        @webcam(this)
        @vm.show_card_result = false
        @vm.show_canvas = false
        @vm.show_cam = true
        @vm.camera_error = true
        @vm.show_img = true
        @vm.show_loading = false
        @vm.show_spin = false
        @vm.show_retry = false
        @vm.show_tracking = false
        @vm.show_all = true
        @vm.show_ip_cam = false
        @vm.personName = "未对比"
        @vm.sex = "未对比"
        @vm.birthday = "未对比"
        @vm.nation = "未对比"
        @vm.personId = "未对比"
        @vm.address = "未对比"
        @vm.startDate = "未对比"
        @vm.endDate = "未对比"
        @vm.department = "未对比"
        @vm.imgPath = "未对比"
        @vm.status = "未对比"
        @vm.result = "未对比"
        @vm.com = "0%"
        @vm.amount_compare = 0
        @vm.source_cam = 'usb摄像头'
        @mode = 'usb'

        @vm.show_upload_canvas = false
        @initpage(this)
        @vm.compare_result = ""
        @vm.show_results = true
        @vm.next_action = "读卡"
        #$("#show_result_pass").remove();
        #@nprocess()
        #@auto_Interval()
        #@spin()
        $('#vedio').attr('style', 'position: absolute;left: 266px;top: 223px;')
        @count_day_amchart(this,@sd.pay.items)
        #@chart_active()
        @count_day_highchart(this,@sd.pay.items)
        @datatable_init(this)
        #@clock_create()
        @init_ip_cam()
        @refresh_page()
        
        #$("#fadein").attr('style', "display:block;");

    refresh_page:() =>
        if compare_card.length
            compare_card.splice(0,compare_card.length)
        if compare_result.length
            compare_result.splice(0,compare_result.length)

    change_cam_modal:() =>
        (new FaceQuickChangeCam(@sd, this,@mode)).attach()

    change_cam:(selected) =>
        #selected = $("#cam_option").val()
        @mode = selected
        @check_cam_change(@mode,this)
        if @mode is "ip"
            @source_cam = 'ip摄像头'
            @vm.show_ip_cam = true
            @ip_camera();

            $("#face_ul").css("padding-top","137px")
            $("#face_portlet").css("height","333px")
            $("#face_no_result").css("padding-top","120px")
        else
            @source_cam = 'usb摄像头'
            @vm.show_ip_cam = false
            if @vm.show_img
                $("#face_ul").css("padding-top","50px")
            else
                $("#face_ul").css("padding-top","185px")
            $("#face_portlet").css("height","395px")
            $("#face_no_result").css("padding-top","170px")

        @vm.source_cam = @source_cam
    
    check_cam_change:(mode,page) =>
        if mode is "usb"
            if @vm.camera_error
                ((window.clearInterval(i)) for i in compare_Interval)
            else
                @auto_Interval();
        else
            #cam_url = 'http://' + @sd.host.split(':')[0] + ':7788' + '/cam'
            cam_url = 'http://localhost:7788/cam'
            $.ajax
                type:'get',
                url: cam_url,
                error: (e) ->
                    ((window.clearInterval(i)) for i in compare_Interval)
                success: (e) ->
                    ip_video = document.getElementById("videoplayer");
                    ip_video.src = cam_url
                    page.auto_Interval();

    init_ip_cam:() =>
        ip_video = document.getElementById("videoplayer");
        #cam_url = 'http://' + @sd.host.split(':')[0] + ':7788' + '/cam'
        cam_url = 'http://localhost:7788/cam'
        ip_video.src = cam_url

    ip_camera:() =>
        @auto_Interval();

    ipcam_takesnap:() =>
        video = document.getElementById("videoplayer");
        facecut = document.getElementById('mirror');
        cxt = facecut.getContext("2d");
        cxt.drawImage(video,300, 80, 820, 640,0,0,164,128);
        imgData = facecut.toDataURL('png');
        dataURL = facecut.toDataURL("image/jpg");
        filename = @sd.register.items["account"] + "_" + @personal_id + "_own.jpg";
        @_upload(this,dataURL,filename,@sd.host,true);
        
        @vm.show_canvas = true;
        @vm.show_img = false;


    remove_all:() =>
        #$("#div_result").remove()
        @frozen()
        chain = new Chain
        chain.chain @sd.update("all")
        show_chain_progress(chain).done =>
            @attach()
            if $("#vedio").length > 0
                @auto_Interval()

    datatable_init: (page) =>
        $(`function() {
            var table = $("#log-table1").DataTable(dtable_opt({
                /*retrieve: true,
                bSort: false,
                scrollX: true,*/
                destroy:true,
                bProcessing: true,
                bServerSide: true,
                sAjaxSource: "http://" + page.sd.host + "/api/searchRecord",
                aoColumnDefs: [
                  {
                    "aTargets": [0],
                    "mData": null,
                    "bSortable": false,
                    "bSearchable": false,
                    "mRender": function(data, type, full) {
                        return  "<img src=http://" + page.sd.host + "/images" + full[0].replace(" ", "%20") + " style='height: 20px;width: 20px;'>";
                    }
                  }, {
                    "aTargets": [1],
                    "mData": null,
                    "bSortable": false,
                    "bSearchable": false,
                    "mRender": function(data, type, full) {
                        return  "<img src=http://" + page.sd.host + "/images" + full[1].replace(" ", "%20") + " style='height: 20px;width: 20px;'>";
                    }
                  }
                ],
                fnServerData: function(sSource, aoData, fnCallback) {
                  aoData.push({
                    "name": "account",
                    "value": page.sd.register.items["account"]
                  });
                  return $.ajax({
                    "type": 'post',
                    "url": sSource,
                    "dataType": "json",
                    "data": aoData,
                    "success": function(resp) {
                      //page.count_day(page,page.sd.pay.items);
                      try{
                        return fnCallback(resp);
                       }catch(e){
                        return
                       }
                    },
                    "error": function(e) {
                      return console.log('error');
                    }
                  });
                }
            }));
            $(".dataTables_filter input").addClass("m-wrap small");
            $(".dataTables_length select").addClass("m-wrap small");

            $('#log-table1 tbody').on( 'click', 'a', function () {
                var data = table.row( $(this).parents('tr') ).data();
                page.record_detail(data[ 3 ]);
            });
        }`)

    count_day_highchart: (page,items) =>
        $(`function () { 
            var myDate = new Date(); //获取今天日期
            myDate.setDate(myDate.getDate() - 9);
            var dateArray = []; 
            var dateTemp; 
            var total_count = {}
            var flag = 1; 
            var total = [];
            page.vm.amount_compare = 0;
            for (var i = 0; i <= 9; i++) {
                dateTemp = (myDate.getMonth()+1)+"月"+myDate.getDate();
                dateArray.push(dateTemp);
                myDate.setDate(myDate.getDate() + flag);
            }
            //var total = [29.9, 71.5, 106.4, 129.2, 144.0, 176.0, 135.6, 148.5, 216.4, 194.1];

            for (var i = 0; i < dateArray.length; i++) {
                total_count[dateArray[i]] = 0;
            }

            Array.prototype.Exists=function(v){
                var b=false;
                for(var i=0;i<this.length;i++){
                    if(this[i]==v){
                        b=true;
                        break;
                    }
                }
                return b;
            }

            for (var i = 0; i < items.length; i++) {
                var strdate = parseInt(items[i].created.split(" ")[0].split("-")[1]) + '月' + parseInt(items[i].created.split(" ")[0].split("-")[2]);
                if ( dateArray.Exists(strdate)) {
                    total_count[strdate] = total_count[strdate] + 1;
                }
            }

            for (var i = 0; i < dateArray.length; i++) {
                page.vm.amount_compare = page.vm.amount_compare + total_count[dateArray[i]];
                total.push(total_count[dateArray[i]]);
            }
            page.day_chart(dateArray,total);
        }`)

    day_chart: (time,total) =>
        $(`function () {
            $('#day_chart').highcharts({
                chart: {
                    type: 'areaspline',
                    marginRight: 10,
                    plotBorderColor:"rgb(255, 255, 255)",
                    plotBorderWidth:1
                },
                title: {
                    text: ''
                },
                subtitle: {
                    text: ''
                },
                exporting: {
                    enabled: false
                },
                credits: {
                    enabled:false
                },
                tooltip: {
                    formatter: function () {
                        return this.x + '<br/>' +
                               '<b>' + this.series.name + ':' +'</b>' + Highcharts.numberFormat(this.y, 0);
                    },
                    style: {
                        color:'#fff',
                        fontSize:'12px',
                        opacity:0.8,
                        fontFamily:"Microsoft Yahei"
                    },
                    borderRadius:0,
                    borderColor:'#000',
                    backgroundColor:'#000'
                },
                xAxis: {
                    categories: time,
                    labels:{
                        style: { 
                            "fontFamily": "Microsoft Yahei" 
                        }
                    }
                },
                yAxis: {
                    title: {
                        text: ''
                    },
                    min:-1,
                    tickColor:"rgba(0,0,0,0)",
                    tickWidth: 0,
                    gridLineColor: 'rgba(0,0,0,0)',
                    labels:{
                        enabled:false
                    }
                },
                plotOptions: {
                    areaspline: {
                        threshold: null,
                        states: {
                            hover: {
                                lineWidth: 2
                            }
                        },
                        fillOpacity: 0.2,
                        marker: {
                            enabled: true,
                            symbol: 'circle',
                            radius: 5.0,
                            lineWidth: 3,
                            lineColor: "#1796f9",
                            fillColor:"#fff",
                            states: {
                                hover: {
                                    enabled: true
                                }
                            }
                        },
                        lineWidth: 2
                    }
                },
                series: [{
                    name: '对比次数',
                    data: total,
                    showInLegend: false
                }]
            });
        }`);

    
    count_day_amchart: (page,items) =>
        $(`function () {
            function Appendzero(obj)  
            {  
                if(obj<10) return "0" +""+ obj;  
                else return obj;  
            }

            var myDate = new Date(); //获取今天日期

            myDate.setDate(myDate.getDate() - 9);
            var dateArray = []; 
            var dateTemp; 
            var total_count = {};
            var average_count = {};
            var flag = 1; 
            var total = [];
            for (var i = 0; i <= 9; i++) {
                dateTemp = (myDate.getFullYear() + '-' + Appendzero(myDate.getMonth()+1)) + "-" + Appendzero(myDate.getDate());
                dateArray.push(dateTemp);
                myDate.setDate(myDate.getDate() + flag);
            }
            for (var i = 0; i < dateArray.length; i++) {
                total_count[dateArray[i]] = 0;
                average_count[dateArray[i]] = 0;
            }

            Array.prototype.Exists=function(v){
                var b=false;
                for(var i=0;i<this.length;i++){
                    if(this[i]==v){
                        b=true;
                        break;
                    }
                }
                return b;
            }

            for (var i = 0; i < items.length; i++) {
                var strdate = items[i].created.split(" ")[0].split("-")[0] + '-' + items[i].created.split(" ")[0].split("-")[1] + '-' + items[i].created.split(" ")[0].split("-")[2];
                average_count[items[i].created.split(" ")[0]] = average_count[items[i].created.split(" ")[0]] + parseInt(items[i].confidence)
                if ( dateArray.Exists(strdate)) {
                    total_count[strdate] = total_count[strdate] + 1;
                }
            }

            for (var i = 0; i < dateArray.length; i++) {
                total.push(total_count[dateArray[i]]);
                if (total_count[dateArray[i]] !== 0) {
                    average_count[dateArray[i]] = parseInt(average_count[dateArray[i]] / total_count[dateArray[i]]);
                }
            }
            page.grab_data(dateArray,total,average_count)
        }`)
    
    grab_data:(dateArray,total,average_count) =>
        chartdata1 = [{
              "date": "2012-01-01",
              "rate": 227,
              "townName": "New York",
              "townName2": "New York",
              "townSize": 25,
              "average": 40
            }, {
              "date": "2012-01-02",
              "rate": 371,
              "townName": "Washington",
              "townSize": 14,
              "average": 38
            }, {
              "date": "2012-01-03",
              "rate": 433,
              "townName": "Wilmington",
              "townSize": 6,
              "average": 34
            }, {
              "date": "2012-01-04",
              "rate": 345,
              "townName": "Jacksonville",
              "townSize": 7,
              "average": 30
            }, {
              "date": "2012-01-05",
              "rate": 480,
              "townName": "Miami",
              "townName2": "Miami",
              "townSize": 10,
              "average": 25
            }, {
              "date": "2012-01-06",
              "rate": 386,
              "townName": "Tallahassee",
              "townSize": 7,
              "average": 30
            }, {
              "date": "2012-01-07",
              "rate": 348,
              "townName": "New Orleans",
              "townSize": 10,
              "average": 29
            }, {
              "date": "2012-01-08",
              "rate": 238,
              "townName": "Houston",
              "townName2": "Houston",
              "townSize": 16,
              "average": 29
            }, {
              "date": "2012-01-09",
              "rate": 218,
              "townName": "Dalas",
              "townSize": 17,
              "average": 32
            }, {
              "date": "2012-01-10",
              "rate": 349,
              "townName": "Oklahoma City",
              "townSize": 11,
              "average": 35
            }]

        chartdata = []
        for i in [0..dateArray.length - 1]
            chartdata.push {"date":dateArray[i],"rate":total[i],"townName":"","townSize":10,"average":average_count[dateArray[i]]}
        @chart_active(chartdata)

    chart_active: (chartData) =>
        $(`function() {
            /*var chartData = [ {
              "date": "2012-01-01",
              "distance": 227,
              "townName": "New York",
              "townName2": "New York",
              "townSize": 25,
              "latitude": 40
            }, {
              "date": "2012-01-02",
              "distance": 371,
              "townName": "Washington",
              "townSize": 14,
              "latitude": 38
            }, {
              "date": "2012-01-03",
              "distance": 433,
              "townName": "Wilmington",
              "townSize": 6,
              "latitude": 34
            }, {
              "date": "2012-01-04",
              "distance": 345,
              "townName": "Jacksonville",
              "townSize": 7,
              "latitude": 30
            }, {
              "date": "2012-01-05",
              "distance": 480,
              "townName": "Miami",
              "townName2": "Miami",
              "townSize": 10,
              "latitude": 25
            }, {
              "date": "2012-01-06",
              "distance": 386,
              "townName": "Tallahassee",
              "townSize": 7,
              "latitude": 30
            }, {
              "date": "2012-01-07",
              "distance": 348,
              "townName": "New Orleans",
              "townSize": 10,
              "latitude": 29
            }, {
              "date": "2012-01-08",
              "distance": 238,
              "townName": "Houston",
              "townName2": "Houston",
              "townSize": 16,
              "latitude": 29
            }, {
              "date": "2012-01-09",
              "distance": 218,
              "townName": "Dalas",
              "townSize": 17,
              "latitude": 32
            }, {
              "date": "2012-01-10",
              "distance": 349,
              "townName": "Oklahoma City",
              "townSize": 11,
              "latitude": 35
            }, {
              "date": "2012-01-11",
              "distance": 603,
              "townName": "Kansas City",
              "townSize": 10,
              "latitude": 39
            }, {
              "date": "2012-01-12",
              "distance": 534,
              "townName": "Denver",
              "townName2": "Denver",
              "townSize": 18,
              "latitude": 39
            }, {
              "date": "2012-01-13",
              "townName": "Salt Lake City",
              "townSize": 12,
              "distance": 425,
              "latitude": 40,
              "alpha": 0.4
            }, {
              "date": "2012-01-14",
              "latitude": 36,
              "distance": 425,
              "townName": "Las Vegas",
              "townName2": "Las Vegas",
              "bulletClass": "lastBullet"
            }];*/
            var chart = AmCharts.makeChart( "amchart", {

              "type": "serial",
              "theme": "light",
              "fontFamily":"Microsoft YaHei",
              
              "dataDateFormat": "YYYY-MM-DD",
              "dataProvider": chartData,

              "addClassNames": true,
              "startDuration": 1,
              //"color": "#FFFFFF",
              "marginLeft": 0,

              "categoryField": "date",
              "categoryAxis": {
                "parseDates": true,
                "minPeriod": "DD",
                "autoGridCount": false,
                "gridCount": 50,
                "gridAlpha": 0.1,
                "gridColor": "#FFFFFF",
                "axisColor": "#555555",
                "dateFormats": [ {
                  "period": 'DD',
                  "format": 'DD'
                }, {
                  "period": 'WW',
                  "format": 'MMM DD'
                }, {
                  "period": 'MM',
                  "format": 'MMM'
                }, {
                  "period": 'YYYY',
                  "format": 'YYYY'
                } ]
              },

              "valueAxes": [ {
                "id": "a1",
                "title": "对比次数",
                "gridAlpha": 0,
                "axisAlpha": 0
              }, {
                "id": "a2",
                "position": "right",
                "gridAlpha": 0,
                "axisAlpha": 0,
                "labelsEnabled": false
              }],
              "graphs": [ {
                "id": "g1",
                "valueField": "rate",
                "title": "对比次数",
                "type": "column",
                "fillAlphas": 0.9,
                "valueAxis": "a1",
                "balloonText": "[[value]] 次",
                "legendValueText": "[[value]] 次",
                "legendPeriodValueText": "总共: [[value.sum]] 次",
                "lineColor": "rgba(124, 181, 236,0.5)",
                "alphaField": "alpha"
              }, {
                "id": "g2",
                "valueField": "average",
                "classNameField": "bulletClass",
                "title": "平均相似度",
                "type": "line",
                "valueAxis": "a2",
                "lineColor": "rgb(137, 196, 244)",
                "lineThickness": 1,
                "legendValueText": "[[value]] %",
                "descriptionField": "townName",
                "bullet": "round",
                "bulletSizeField": "townSize",
                "bulletBorderColor": "rgb(23, 150, 249)",
                "bulletBorderAlpha": 1,
                "bulletBorderThickness": 3,
                "bulletColor": "rgba(255,255,255,1)",
                "labelText": "[[townName2]]",
                "labelPosition": "right",
                "balloonText": "平均相似度:[[value]] %",
                "showBalloon": true,
                "animationPlayed": true
              }],

              "chartCursor": {
                "zoomable": false,
                "categoryBalloonDateFormat": "DD",
                "cursorAlpha": 0,
                "valueBalloonsEnabled": false
              },
              "legend": {
                "bulletType": "round",
                "equalWidths": false,
                "valueWidth": 120,
                "useGraphSettings": true,
                //"color": "#FFFFFF"
              }
            } );
        }`)

    spin:() =>
        opts = {
            lines: 13, # loading小块的数量
            length: 7, # 小块的长度
            width: 4, # 小块的宽度
            radius: 10, # 整个圆形的半径
            corners: 1, # 小块的圆角，越大则越圆
            rotate: 0, # loading动画的旋转度数，貌似没什么实际作用
            color: '#000', # 颜色
            speed: 1, # 变换速度
            trail: 60, # 余晖的百分比
            shadow: false, # 是否渲染出阴影
            hwaccel: false, # 是否启用硬件加速
            className: 'spinner', # 给loading添加的css样式名
            zIndex: 2e9, # The z-index (defaults to 2000000000)
            top: 'auto', # Top position relative to parent in px
            left: 'auto' # Left position relative to parent in px
        }

        target = document.getElementById('foo');
        spinner = new Spinner(opts).spin(target);

    face_tracking:() =>
        $(`function() {
            try{
                    var video = document.getElementById('video');
                    var canvas = document.getElementById('canvas');
                    var context = canvas.getContext('2d');

                    var tracker = new tracking.ObjectTracker('face');
                    tracker.setInitialScale(4);
                    tracker.setStepSize(2);
                    tracker.setEdgesDensity(0.1);

                    tracking.track('#video', tracker, { camera: true });

                    tracker.on('track', function(event) {
                      context.clearRect(0, 0, canvas.width, canvas.height);

                      event.data.forEach(function(rect) {
                        context.strokeStyle = '#a64ceb';
                        context.strokeRect(rect.x, rect.y, rect.width, rect.height);
                        context.font = '11px Helvetica';
                        context.fillStyle = "#fff";
                        context.fillText('x: ' + rect.x + 'px', rect.x + rect.width + 5, rect.y + 11);
                        context.fillText('y: ' + rect.y + 'px', rect.x + rect.width + 5, rect.y + 22);
                      });
                    });

                    var gui = new dat.GUI();
                    gui.add(tracker, 'edgesDensity', 0.1, 0.5).step(0.01);
                    gui.add(tracker, 'initialScale', 1.0, 10.0).step(0.1);
                    gui.add(tracker, 'stepSize', 1, 5).step(0.1);
            }catch(e){
                console.log(e);
            }
        }`)

    retry_cameras:() =>
        $(`function() {
            try{
                    var video = document.getElementById('video');
                    var canvas = document.getElementById('canvas');
                    var context = canvas.getContext('2d');

                    var tracker = new tracking.ObjectTracker('face');
                    tracker.setInitialScale(4);
                    tracker.setStepSize(2);
                    tracker.setEdgesDensity(0.1);

                    tracking.track('#video', tracker, { camera: true });

                    tracker.on('track', function(event) {
                      context.clearRect(0, 0, canvas.width, canvas.height);

                      event.data.forEach(function(rect) {
                        context.strokeStyle = '#a64ceb';
                        context.strokeRect(rect.x, rect.y, rect.width, rect.height);
                        context.font = '11px Helvetica';
                        context.fillStyle = "#fff";
                        context.fillText('x: ' + rect.x + 'px', rect.x + rect.width + 5, rect.y + 11);
                        context.fillText('y: ' + rect.y + 'px', rect.x + rect.width + 5, rect.y + 22);
                      });
                    });

                    var gui = new dat.GUI();
                    gui.add(tracker, 'edgesDensity', 0.1, 0.5).step(0.01);
                    gui.add(tracker, 'initialScale', 1.0, 10.0).step(0.1);
                    gui.add(tracker, 'stepSize', 1, 5).step(0.1);
            }catch(e){
                console.log(e);
            }
        }`)

    nprocess:() =>
        NProgress.start()
        setTimeout (=> NProgress.done();$('.fade').removeClass('out')),500

    initpage: (page) =>
        $(`function() {
            $('#form_wizard_1').bootstrapWizard({
                'nextSelector': '.button-next',
                'previousSelector': '.button-previous',
                onTabClick: function (tab, navigation, index) {
                    //alert('on tab click disabled');
                    return false;
                },
                onNext: function (tab, navigation, index) {
                    var total = navigation.find('li').length;
                    var current = index + 1;
                    $('#form_wizard_1').find('.button-next').show();
                    if (current == 2){
                        page.get_card();
                        return false;
                    }else{
                        if (page.vm.show_canvas == false){
                            $('.alert-error', $('#submit_form')).show();
                            return false;
                        }else{
                            page.compare();
                            $('.alert-error', $('#submit_form')).hide();
                        }
                    }
                    
                    // set wizard title
                    $('.step-title', $('#form_wizard_1')).text('Step ' + (index + 1) + ' of ' + total);
                    // set done steps
                    jQuery('li', $('#form_wizard_1')).removeClass("done");
                    var li_list = navigation.find('li');
                    for (var i = 0; i < index; i++) {
                        jQuery(li_list[i]).addClass("done");
                    }

                    if (current == 1) {
                        $('#form_wizard_1').find('.button-previous').hide();
                    } else {
                        $('#form_wizard_1').find('.button-previous').show();
                    }
                    //console.log(page.vm.show_card_result);
                    if (current >= total) {
                        $('#form_wizard_1').find('.button-next').hide();
                        $('#form_wizard_1').find('.button-submit').show();
                        //displayConfirm();
                    } else {
                        $('#form_wizard_1').find('.button-next').show();
                        $('#form_wizard_1').find('.button-submit').hide();
                    }
                    //App.scrollTo($('.page-title'));
                },
                onPrevious: function (tab, navigation, index) {
                    var total = navigation.find('li').length;
                    var current = index + 1;
                    $('.alert-error', $('#submit_form')).hide();
                    // set wizard title
                    $('.step-title', $('#form_wizard_1')).text('Step ' + (index + 1) + ' of ' + total);
                    // set done steps
                    jQuery('li', $('#form_wizard_1')).removeClass("done");
                    var li_list = navigation.find('li');
                    for (var i = 0; i < index; i++) {
                        jQuery(li_list[i]).addClass("done");
                    }

                    if (current == 1) {
                        $('#form_wizard_1').find('.button-previous').hide();
                        $('#form_wizard_1').find('.button-next').hide();
                        page.vm.next_action = "读卡";
                        page.auto_Interval();
                    } else {
                        page.vm.compare_result = "正在比对.....";
                        //$('#div_result').find("#show_result_pass").hide();
                        var pass = document.getElementById('show_result_pass');
                        var mirror = document.getElementById('mirror');
                        pass.src="";
                        mirror.src = "";
                        page.vm.show_canvas = false;
                        $('#form_wizard_1').find('.button-previous').show();
                    }

                    if (current >= total) {
                        $('#form_wizard_1').find('.button-next').hide();
                        $('#form_wizard_1').find('.button-submit').show();
                    } else {
                        if (current == 1){
                            return;
                        }
                        $('#form_wizard_1').find('.button-next').show();
                        $('#form_wizard_1').find('.button-submit').hide();
                    }

                    //App.scrollTo($('.page-title'));
                },
                onTabShow: function (tab, navigation, index) {
                    var total = navigation.find('li').length;
                    var current = index + 1;
                    var $percent = (current / total) * 100;
                    $('#form_wizard_1').find('.bar').css({
                        width: $percent + '%'
                    });
                }
            });
            $('#form_wizard_1').find('.button-next').hide();
            $('#form_wizard_1').find('.button-previous').hide();
            $('#form_wizard_1 .button-submit').click(function () {
                page.attach();
            }).hide();
        }`)

    retry_camera:() =>
        @webcam(this)

    auto_Interval:() =>
        ((window.clearInterval(i)) for i in compare_Interval)
        if compare_Interval.length
            compare_Interval.splice(0,compare_Interval.length)

        @_loop = setInterval((=>
            if !compare_temp.length
                @get_card()
            ), 3000)
        #console.log(compare_Interval);
        compare_Interval.push @_loop

    set_time:(times) =>
        year = times.substring(0,4)
        month = times.substring(4,6)
        day = times.substring(6,8)
        return year + '年' + month + '月' + day + '日'

    get_card: () =>
        try
            query = (new MachineRest('localhost:4567'))
            machine_path = query.get_path '123'
            machine_path.done (data) =>
                path = data.detail
                query = (new MachineRest('localhost:4567'))
                machine_detail = query.get_card '123'
                machine_detail.done (data) =>
                    if data.status is "success"
                        if data.detail.personId in compare_card and 'pass' in compare_result
                            @vm.status = "已通过"
                            @vm.result = "已通过"
                            return

                        $("body").modalmanager "loading"
                        if 'fail' in compare_result or data.detail.personId not in compare_card
                            $("#div_result").css("display","none")
                            if compare_card.length
                                compare_card.splice(0,compare_card.length)

                        @vm.show_all = false
                        @person_msg = JSON.stringify(data.detail)
                        @vm.personName = data.detail.personName
                        @vm.sex = data.detail.sex
                        #@vm.birthday = data.detail.birthday
                        @vm.nation = data.detail.nation
                        @vm.personId = data.detail.personId
                        @vm.address = data.detail.address
                        #@vm.startDate = data.detail.startDate
                        #@vm.endDate = data.detail.endDate
                        @vm.department = data.detail.department
                        @vm.imgPath = data.detail.imgPath
                        @vm.show_card_result = true

                        @vm.birthday = @set_time(data.detail.birthday)
                        @vm.startDate = @set_time(data.detail.startDate)
                        @vm.endDate = @set_time(data.detail.endDate)

                        ###$("#myTab li:eq(1) a").tab "show"
                        $("#myTab li:eq(0)").addClass "done"
                        $('.alert-error', $('#submit_form')).hide()
                        @vm.next_action = "对比"
                        $('#form_wizard_1').find('.bar').css({
                            width: 100 + '%'
                        })###
                        
                        img = new Image()
                        img.src=path + '/person.jpg'
                        img.onload = () =>
                            canvas_cards = document.getElementById("canvas_card")
                            cxt= canvas_cards.getContext("2d")
                            w = Math.min(400, img.width)
                            h = img.height * (w / img.width)
                            canvas_cards.width = w
                            canvas_cards.height = h
                            cxt.drawImage(img,0,0)
                            dataURL = canvas_cards.toDataURL("image/jpg")
                            @personal_id = @vm.personId
                            filename = @sd.register.items["account"] + "_" + @personal_id + "_person.jpg"
                            @_upload("",dataURL,filename,@sd.host,false)
                            if @mode is "usb"
                                @sayCheese.takeSnapshot()
                            else
                                @ipcam_takesnap()
                            @vm.status = "正在上传图片"
                            @vm.result = "正在上传图片"
                            @vm.com = "0%"
                            @vm.show_spin = true
                            compare_card.push @vm.personId
                            compare_temp.push 'get_card'
                            if compare_result.length
                                compare_result.splice(0,compare_result.length)
                            #@compare()
                            #clearInterval @_loop if @_loop?
                    else
                        #@vm.show_retry = false
                        #@vm.show_img = true
                        #$("#div_result").css("display","none")
                        @vm.status = "读卡失败"
                        @vm.result = "读卡失败"
                        ###@vm.personName = "未对比"
                        @vm.sex = "未对比"
                        @vm.birthday = "未对比"
                        @vm.nation = "未对比"
                        @vm.personId = "未对比"
                        @vm.address = "未对比"
                        @vm.startDate = "未对比"
                        @vm.endDate = "未对比"
                        @vm.department = "未对比"
                        @vm.imgPath = "未对比"###
                        #@vm.com = "0%"
                        if compare_card.length
                            compare_card.splice(0,compare_card.length)
                        if compare_result.length
                            compare_result.splice(0,compare_result.length)
                        #@vm.show_card_result = false
                        #$('.alert-error', $('#submit_form')).show()
                        #(new MessageModal(@vm.lang.get_card_error)).attach()

                machine_detail.fail =>
                    @vm.show_retry = false
                    @vm.status = "读卡器未连接"
                    @vm.result = "读卡器未连接"
                    @vm.com = "0%"
                    $("#gritter-notice-wrapper").remove()
                    @show_tips(@vm.result)
                    #@vm.show_card_result = false
                    #$('.alert-error', $('#submit_form')).show()
                    #return (new MessageModal(@vm.lang.get_card_error)).attach()
                    #console.log('error');
            machine_path.fail =>
                @vm.status = "未安装驱动"
                @vm.result = "未安装驱动"
                @vm.com = "0%"
                $("#gritter-notice-wrapper").remove()
                @show_tips(@vm.result)
        catch e
            console.log e
           
    show_tips:(tips) =>
        $.extend($.gritter.options, 
            class_name: 'gritter', 
            position: 'bottom-right', 
            fade_in_speed: 1000, 
            fade_out_speed: 100, 
            time: 10000
        );
        $.gritter.add(
            title: '提示',
            text: tips
        );

    check_remain:() =>
        if parseInt(@sd.register.items["remain"]) <= 0
            return false
        return true

    compare: () =>
        try
            if @check_remain()
                query = (new MachineRest(@sd.host))
                machine = query.compare @sd.register.items["account"],@personal_id,@person_msg
                machine.done (data) =>
                    console.log(data);
                   
            else
                @vm.status = "对比次数已用完，请充值"
                @vm.result = "对比次数已用完，请充值"
                @vm.com = "0%"
                #return (new MessageModal('对比次数已用完，请充值')).attach()
        catch e
            console.log e
        
        ###try
            if @check_remain()
                @frozen()
                chain = new Chain
                chain.chain =>
                    (new MachineRest @sd.host).compare @sd.register.items["account"],@personal_id,@person_msg
                chain.chain @sd.update("all"),true
                show_chain_progress(chain).done =>
                    console.log 'compare-success'
            else
                @vm.status = "对比次数已用完，请充值"
                @vm.result = "对比次数已用完，请充值"
                @vm.com = "0%"
                #return (new MessageModal('对比次数已用完，请充值')).attach()
        catch e
            console.log e###
    
    show_stamp: (con) =>
        ###$('#form_wizard_1').find('.button-previous').hide()
        if parseInt(con) < 50
            @vm.compare_result = "识别度过低,请对准摄像头"
            $("#show_result_pass").stamper(
                image : "images/failed.png",
                scale : 3,
                speed : 300
            )
        else
            @vm.compare_result = "识别成功,相似度为:" + con + "%"
            $("#show_result_pass").stamper(
                image : "images/pass.png",
                scale : 3,
                speed : 300
            )###

        @vm.show_loading = true
        @vm.show_spin = false
        @vm.show_all = true
        $("#div_result").css("display","block")
        if parseInt(con) < 60
            @vm.status = "对比完成"
            @vm.result = "很抱歉,不通过"
            @vm.com = parseInt(con) + "%"
            $("#show_result_pass").stamper(
                image : "images/failed.png",
                scale : 3,
                speed : 300
            )
            compare_result.push 'fail'
        else
            @vm.status = "对比完成"
            @vm.result = "恭喜你,通过"
            @vm.com = parseInt(con) + "%"
            $("#show_result_pass").stamper(
                image : "images/pass.png",
                scale : 3,
                speed : 300
            )
            compare_result.push 'pass'
        if compare_temp.length
            compare_temp.splice(0,compare_temp.length)
        @vm.show_retry = true

    show_stamp_new: (con) =>
        #$(".modal-backdrop").hide()
        $("body").modalmanager "removeLoading"
        @vm.show_loading = true
        @vm.show_spin = false
        @vm.show_all = true
        $("#div_result").css("display","block")
        if @mode is "usb"
            $("#face_ul").css("padding-top","185px")
        else
            $("#face_ul").css("padding-top","137px")

        if parseInt(con) < 60
            @vm.status = "对比完成"
            @vm.result = "很抱歉,不通过"
            @vm.com = parseInt(con) + "%"
            img = document.getElementById('result_img');
            img.src = 'images/fail_img.png';
            compare_result.push 'fail'
        else
            @vm.status = "对比完成"
            @vm.result = "恭喜你,通过"
            @vm.com = parseInt(con) + "%"
            img = document.getElementById('result_img');
            img.src = 'images/pass_img.png';
            compare_result.push 'pass'
        if compare_temp.length
            compare_temp.splice(0,compare_temp.length)
        @vm.show_retry = true

    getpic: () =>
        query = (new MachineRest('localhost:4567'))
        machine_detail = query.get_pic "123"
        machine_detail.done (data) =>
            console.log(data);
        console.log 123123
    
    face_track:(page) =>
        $(`function() {
            var video = document.getElementById('video');
            var canvas = document.getElementById('canvas');
            var context = canvas.getContext('2d');
            page.vm.show_tracking = true;

            var tracker = new tracking.ObjectTracker('face');
            /*tracker.setInitialScale(4);
            tracker.setStepSize(2);
            tracker.setEdgesDensity(0.1);*/

            tracking.track('#video', tracker, { camera: true });
            
            tracker.on('track', function(event) {
              context.clearRect(0, 0, canvas.width, canvas.height);

              event.data.forEach(function(rect) {
                context.strokeStyle = '#a64ceb';
                context.strokeRect(rect.x, rect.y, rect.width, rect.height);
                page.x1 = rect.width;
                page.y1 = rect.height;
                page.x2 = rect.x;
                page.y2 = rect.y;
                /*context.font = '11px Helvetica';
                context.fillStyle = "#fff";
                context.fillText('x: ' + rect.x + 'px', rect.x + rect.width + 5, rect.y + 11);
                context.fillText('y: ' + rect.y + 'px', rect.x + rect.width + 5, rect.y + 22);*/
              });
            });

            /*var gui = new dat.GUI();
            gui.add(tracker, 'edgesDensity', 0.1, 0.5).step(0.01);
            gui.add(tracker, 'initialScale', 1.0, 10.0).step(0.1);
            gui.add(tracker, 'stepSize', 1, 5).step(0.1);*/
        }`)

    webcam: (page) =>
        $(`function() {
              var sayCheese = new SayCheese('#webcam', { audio: false });
              page.sayCheese = sayCheese;
              sayCheese.on('start', function() {
                page.vm.camera_error = false;
                //page.face_track(page);
                page.auto_Interval();
              })
              function base64Img2Blob(code){
                        var parts = code.split(';base64,');
                        var contentType = parts[0].split(':')[1];
                        var raw = window.atob(parts[1]);
                        var rawLength = raw.length;

                        var uInt8Array = new Uint8Array(rawLength);

                        for (var i = 0; i < rawLength; ++i) {
                          uInt8Array[i] = raw.charCodeAt(i);
                        }

                        return new Blob([uInt8Array], {type: contentType}); 
                    };
                    function downloadFile(fileName, content){
                       
                        var aLink = document.createElement('a');
                        var blob = base64Img2Blob(content); //new Blob([content]);
                        //page.compare(blob);
                        var evt = document.createEvent("HTMLEvents");
                        evt.initEvent("click", false, false);//initEvent 不加后两个参数在FF下会报错
                        aLink.download = fileName;
                        aLink.href = URL.createObjectURL(blob);
                        aLink.dispatchEvent(evt);
                    };      
                     
              sayCheese.on('snapshot', function(snapshot) {
                try{
                    //console.log(snapshot);
                    //var mirror = document.getElementById('mirror');
                    //mirror.width = snapshot.width;
                    //mirror.height = snapshot.height;

                   
                    var mirror = new Image();
                    var imgData = snapshot.toDataURL('png');
                    mirror.src = imgData;
                    mirror.onload = function(){
                        var facecut = document.getElementById('mirror');
                        var cxt = facecut.getContext("2d");
                        cxt.drawImage(mirror,190,87,264,282,0,0,120,126);
                        var dataURL = facecut.toDataURL("image/jpg");
                        var filename = page.sd.register.items["account"] + "_" + page.personal_id +"_own.jpg";
                        page._upload(page,dataURL,filename,page.sd.host,true);
                    }
                    page.vm.show_canvas = true;

                    page.vm.show_img = false;
                    //var mirror = document.getElementById('mirror');
                    //mirror.width = snapshot.width;
                    //mirror.height = snapshot.height;

                    var imgData = snapshot.toDataURL('png');
                    //mirror.src = imgData;
                    //$('#mirror').attr('style', 'background-image:url('+ imgData +');background-position: 358px 308px;width: 107px;height: 126px;background-size: 200%;')
                    page.vm.show_canvas = true;
                    //page._upload(page,snapshot.toDataURL("image/jpg"),filename,page.sd.host,true);
                }
                catch(e){
                    console.log(e);
                }
              });
            
              sayCheese.start();
              
              $('#shot').click(function () {
                //console.log(sayCheese);
                try{
                    sayCheese.takeSnapshot();
                }catch(e){
                    return;
                }
              });
        }`)

    _upload: (page,base64,filename,host,compare) =>
        $(`function() {
            try{
                function sumitImageFile(base64Codes){
                    var form=document.forms[0];
                    var formData = new FormData(form);  
                    formData.append("imageName",convertBase64UrlToBlob(base64Codes),filename);  
                    $.ajax({
                        url : "http://" + host + "/api/upgrade",
                        //url : "http://192.168.2.122:4569/api/upgrade",
                        type : "POST",
                        data : formData,
                        dataType:"text",
                        processData : false,        
                        contentType : false,
                        beforeSend: function(request) {
                            request.setRequestHeader("Test", "Chenxizhang");
                        },
                        success:function(data){
                            if (compare){
                                page.compare();
                            }
                            //window.location.href="${ctx}"+data;
                            //return (new MessageModal(lang.fileupload.upload_success)).attach();
                        },
                        xhr:function(){            
                            var xhr = new XMLHttpRequest();
                            xhr.upload.addEventListener("progress", function(evt){
                                if (evt.lengthComputable) {
                                    var percentComplete = Math.round(evt.loaded * 100 / evt.total);  
                                    console.log("正在提交."+percentComplete.toString() + '%');        //在控制台打印上传进度
                                }
                            }, false);
                            return xhr;
                        }
                        
                    });
                }
                function convertBase64UrlToBlob(urlData){
                    var bytes=window.atob(urlData.split(',')[1]);       
                    var ab = new ArrayBuffer(bytes.length);
                    var ia = new Uint8Array(ab);
                    for (var i = 0; i < bytes.length; i++) {
                        ia[i] = bytes.charCodeAt(i);
                    }
                    return new Blob( [ab] , {type : 'image/jpeg'});
                }
                sumitImageFile(base64);
            }catch(e){
                console.log(e);
            }
        }`)

    process: (index) =>
        $('#form_wizard').bootstrapWizard(
            rate = (index / 2)
            $('#form_wizard').find('.bar').css({width: rate + '%'})
        )
        if index is 2
            $("#myTab li:eq(1) a").tab "show"

class FaceQuickPage extends DetailTablePage
    constructor: (@sd) ->
        super "facequickpage-", "html/facequickpage.html"
        @dataurl = ""
        @personal_id = ""
        @person_msg = ""
        @sayCheese = ""

        $(@sd).on "compareresult", (e, result) =>
            if result.name is "compareResult"
                @show_stamp(result.confidence)

    define_vm: (vm) =>
     
        vm.lang = lang.facepage
        vm.get_card = @get_card
        vm.compare = @compare

        vm.personName = ""
        vm.sex = ""
        vm.birthday = ""
        vm.nation = ""
        vm.personId = ""
        vm.address = ""
        vm.startDate = ""
        vm.endDate = ""
        vm.department = ""
        vm.imgPath = ""

        vm.show_card_result = false
        vm.show_canvas = false
        vm_show_compare = false
        vm.show_loading = true
        vm.show_cam = true
        vm.checked = false
        vm.upload_pic = @upload_pic

        vm.show_upload_canvas = false
        vm.compare_result = ""
        vm.show_results = true
        vm.next_action = "读卡"
        vm.camera_error = true
        vm.retry_camera = @retry_camera
        vm.retry_cameras = @retry_cameras

    rendered: () =>
        super()
        new WOW().init();
        #@face_tracking()
        @webcam(this)
        @vm.show_card_result = false
        @vm.show_canvas = false
        @vm.show_cam = true
        @vm.camera_error = true
        @vm.show_loading = true

        @vm.show_upload_canvas = false
        @initpage(this)
        @vm.compare_result = ""
        @vm.show_results = true
        @vm.next_action = "读卡"
        #$("#show_result_pass").remove();
        @nprocess()
        #@auto_Interval()
        
    face_tracking:() =>
        $(`function() {
            try{
                    var video = document.getElementById('video');
                    var canvas = document.getElementById('canvas');
                    var context = canvas.getContext('2d');

                    var tracker = new tracking.ObjectTracker('face');
                    tracker.setInitialScale(4);
                    tracker.setStepSize(2);
                    tracker.setEdgesDensity(0.1);

                    tracking.track('#video', tracker, { camera: true });

                    tracker.on('track', function(event) {
                      context.clearRect(0, 0, canvas.width, canvas.height);

                      event.data.forEach(function(rect) {
                        context.strokeStyle = '#a64ceb';
                        context.strokeRect(rect.x, rect.y, rect.width, rect.height);
                        context.font = '11px Helvetica';
                        context.fillStyle = "#fff";
                        context.fillText('x: ' + rect.x + 'px', rect.x + rect.width + 5, rect.y + 11);
                        context.fillText('y: ' + rect.y + 'px', rect.x + rect.width + 5, rect.y + 22);
                      });
                    });

                    var gui = new dat.GUI();
                    gui.add(tracker, 'edgesDensity', 0.1, 0.5).step(0.01);
                    gui.add(tracker, 'initialScale', 1.0, 10.0).step(0.1);
                    gui.add(tracker, 'stepSize', 1, 5).step(0.1);
            }catch(e){
                console.log(e);
            }
        }`)

    retry_cameras:() =>
        $(`function() {
            try{
                    var video = document.getElementById('video');
                    var canvas = document.getElementById('canvas');
                    var context = canvas.getContext('2d');

                    var tracker = new tracking.ObjectTracker('face');
                    tracker.setInitialScale(4);
                    tracker.setStepSize(2);
                    tracker.setEdgesDensity(0.1);

                    tracking.track('#video', tracker, { camera: true });

                    tracker.on('track', function(event) {
                      context.clearRect(0, 0, canvas.width, canvas.height);

                      event.data.forEach(function(rect) {
                        context.strokeStyle = '#a64ceb';
                        context.strokeRect(rect.x, rect.y, rect.width, rect.height);
                        context.font = '11px Helvetica';
                        context.fillStyle = "#fff";
                        context.fillText('x: ' + rect.x + 'px', rect.x + rect.width + 5, rect.y + 11);
                        context.fillText('y: ' + rect.y + 'px', rect.x + rect.width + 5, rect.y + 22);
                      });
                    });

                    var gui = new dat.GUI();
                    gui.add(tracker, 'edgesDensity', 0.1, 0.5).step(0.01);
                    gui.add(tracker, 'initialScale', 1.0, 10.0).step(0.1);
                    gui.add(tracker, 'stepSize', 1, 5).step(0.1);
            }catch(e){
                console.log(e);
            }
        }`)

    nprocess:() =>
        NProgress.start()
        setTimeout (=> NProgress.done();$('.fade').removeClass('out')),500

    initpage: (page) =>
        $(`function() {
            $('#form_wizard_1').bootstrapWizard({
                'nextSelector': '.button-next',
                'previousSelector': '.button-previous',
                onTabClick: function (tab, navigation, index) {
                    //alert('on tab click disabled');
                    return false;
                },
                onNext: function (tab, navigation, index) {
                    var total = navigation.find('li').length;
                    var current = index + 1;
                    $('#form_wizard_1').find('.button-next').show();
                    if (current == 2){
                        page.get_card();
                        return false;
                    }else{
                        if (page.vm.show_canvas == false){
                            $('.alert-error', $('#submit_form')).show();
                            return false;
                        }else{
                            page.compare();
                            $('.alert-error', $('#submit_form')).hide();
                        }
                    }
                    
                    // set wizard title
                    $('.step-title', $('#form_wizard_1')).text('Step ' + (index + 1) + ' of ' + total);
                    // set done steps
                    jQuery('li', $('#form_wizard_1')).removeClass("done");
                    var li_list = navigation.find('li');
                    for (var i = 0; i < index; i++) {
                        jQuery(li_list[i]).addClass("done");
                    }

                    if (current == 1) {
                        $('#form_wizard_1').find('.button-previous').hide();
                    } else {
                        $('#form_wizard_1').find('.button-previous').show();
                    }
                    //console.log(page.vm.show_card_result);
                    if (current >= total) {
                        $('#form_wizard_1').find('.button-next').hide();
                        $('#form_wizard_1').find('.button-submit').show();
                        //displayConfirm();
                    } else {
                        $('#form_wizard_1').find('.button-next').show();
                        $('#form_wizard_1').find('.button-submit').hide();
                    }
                    //App.scrollTo($('.page-title'));
                },
                onPrevious: function (tab, navigation, index) {
                    var total = navigation.find('li').length;
                    var current = index + 1;
                    $('.alert-error', $('#submit_form')).hide();
                    // set wizard title
                    $('.step-title', $('#form_wizard_1')).text('Step ' + (index + 1) + ' of ' + total);
                    // set done steps
                    jQuery('li', $('#form_wizard_1')).removeClass("done");
                    var li_list = navigation.find('li');
                    for (var i = 0; i < index; i++) {
                        jQuery(li_list[i]).addClass("done");
                    }

                    if (current == 1) {
                        $('#form_wizard_1').find('.button-previous').hide();
                        $('#form_wizard_1').find('.button-next').hide();
                        page.vm.next_action = "读卡";
                        page.auto_Interval();
                    } else {
                        page.vm.compare_result = "正在比对.....";
                        //$('#div_result').find("#show_result_pass").hide();
                        var pass = document.getElementById('show_result_pass');
                        var mirror = document.getElementById('mirror');
                        pass.src="";
                        mirror.src = "";
                        page.vm.show_canvas = false;
                        $('#form_wizard_1').find('.button-previous').show();
                    }

                    if (current >= total) {
                        $('#form_wizard_1').find('.button-next').hide();
                        $('#form_wizard_1').find('.button-submit').show();
                    } else {
                        if (current == 1){
                            return;
                        }
                        $('#form_wizard_1').find('.button-next').show();
                        $('#form_wizard_1').find('.button-submit').hide();
                    }

                    //App.scrollTo($('.page-title'));
                },
                onTabShow: function (tab, navigation, index) {
                    var total = navigation.find('li').length;
                    var current = index + 1;
                    var $percent = (current / total) * 100;
                    $('#form_wizard_1').find('.bar').css({
                        width: $percent + '%'
                    });
                }
            });
            $('#form_wizard_1').find('.button-next').hide();
            $('#form_wizard_1').find('.button-previous').hide();
            $('#form_wizard_1 .button-submit').click(function () {
                page.attach();
            }).hide();
        }`)

    retry_camera:() =>
        @webcam(this)

    auto_Interval:() =>
        if !compare_Interval.length
            @_loop = setInterval((=>
                @get_card()
                ), 3000)
            compare_Interval.push @_loop

    get_card: () =>
        try
            query = (new MachineRest('localhost:4567'))
            machine_detail = query.get_path '123'
            machine_detail.done (data) =>
                path = data.detail
                query = (new MachineRest('localhost:4567'))
                machine_detail = query.get_card '123'
                machine_detail.done (data) =>
                    if data.status is "success"
                        @person_msg = JSON.stringify(data.detail)
                        @vm.personName = data.detail.personName
                        @vm.sex = data.detail.sex
                        @vm.birthday = data.detail.birthday
                        @vm.nation = data.detail.nation
                        @vm.personId = data.detail.personId
                        @vm.address = data.detail.address
                        @vm.startDate = data.detail.startDate
                        @vm.endDate = data.detail.endDate
                        @vm.department = data.detail.department
                        @vm.imgPath = data.detail.imgPath
                        @vm.show_card_result = true

                        canvas_cards = document.getElementById("canvas_card")
                        cxt= canvas_cards.getContext("2d")

                        $("#myTab li:eq(1) a").tab "show"
                        $("#myTab li:eq(0)").addClass "done"
                        $('.alert-error', $('#submit_form')).hide()
                        @vm.next_action = "对比"
                        $('#form_wizard_1').find('.bar').css({
                            width: 100 + '%'
                        })

                        img = new Image()
                        img.src=path + '/person.jpg'
                        img.onload = () =>
                            w = Math.min(400, img.width)
                            h = img.height * (w / img.width)
                            canvas_cards.width = w
                            canvas_cards.height = h
                            cxt.drawImage(img,0,0)
                            dataURL = canvas_cards.toDataURL("image/jpg")
                            @personal_id = @vm.personId
                            filename = @sd.register.items["account"] + "_" + @personal_id + "_person.jpg"
                            @_upload(dataURL,filename,@sd.host)
                            @sayCheese.takeSnapshot()
                            @compare()
                            clearInterval @_loop if @_loop?
                    else
                        #@vm.show_card_result = false
                        #$('.alert-error', $('#submit_form')).show()
                        #(new MessageModal(@vm.lang.get_card_error)).attach()
                machine_detail.fail =>
                    #@vm.show_card_result = false
                    #$('.alert-error', $('#submit_form')).show()
                    #return (new MessageModal(@vm.lang.get_card_error)).attach()
                    console.log('error');
        catch e
            console.log e
            
    compare: () =>
        try
            @frozen()
            chain = new Chain
            chain.chain =>
                (new MachineRest @sd.host).compare @sd.register.items["account"],@personal_id,@person_msg
            chain.chain @sd.update("all"),true
            show_chain_progress(chain).done =>
                console.log 'compare-success'
        catch e
            console.log e
    
    show_stamp: (con) =>
        $('#form_wizard_1').find('.button-previous').hide()
        @vm.show_loading = false
        if parseInt(con) < 50
            @vm.compare_result = "识别度过低,请对准摄像头"
            $("#show_result_pass").stamper(
                image : "images/failed.png",
                scale : 3,
                speed : 300
            )
        else
            @vm.compare_result = "识别成功,相似度为:" + con + "%"
            $("#show_result_pass").stamper(
                image : "images/pass.png",
                scale : 3,
                speed : 300
            )

    getpic: () =>
        query = (new MachineRest('localhost:4567'))
        machine_detail = query.get_pic "123"
        machine_detail.done (data) =>
            console.log(data);
        console.log 123123

    webcam: (page) =>
        $(`function() {
              var sayCheese = new SayCheese('#webcam', { audio: false });
              page.sayCheese = sayCheese;
              sayCheese.on('start', function() {
                page.vm.camera_error = false;
				
                var video = document.getElementById('video');
                var canvas = document.getElementById('canvas');
                var context = canvas.getContext('2d');

                var tracker = new tracking.ObjectTracker('face');
                tracker.setInitialScale(4);
                tracker.setStepSize(2);
                tracker.setEdgesDensity(0.1);

                tracking.track('#video', tracker, { camera: true });
				page.auto_Interval();
                tracker.on('track', function(event) {
                  context.clearRect(0, 0, canvas.width, canvas.height);

                  event.data.forEach(function(rect) {
                    context.strokeStyle = '#a64ceb';
                    context.strokeRect(rect.x, rect.y, rect.width, rect.height);
                    context.font = '11px Helvetica';
                    context.fillStyle = "#fff";
                    context.fillText('x: ' + rect.x + 'px', rect.x + rect.width + 5, rect.y + 11);
                    context.fillText('y: ' + rect.y + 'px', rect.x + rect.width + 5, rect.y + 22);
                  });
                });

                /*var gui = new dat.GUI();
                gui.add(tracker, 'edgesDensity', 0.1, 0.5).step(0.01);
                gui.add(tracker, 'initialScale', 1.0, 10.0).step(0.1);
                gui.add(tracker, 'stepSize', 1, 5).step(0.1);*/
              })
              function base64Img2Blob(code){
                        var parts = code.split(';base64,');
                        var contentType = parts[0].split(':')[1];
                        var raw = window.atob(parts[1]);
                        var rawLength = raw.length;

                        var uInt8Array = new Uint8Array(rawLength);

                        for (var i = 0; i < rawLength; ++i) {
                          uInt8Array[i] = raw.charCodeAt(i);
                        }

                        return new Blob([uInt8Array], {type: contentType}); 
                    };
                    function downloadFile(fileName, content){
                       
                        var aLink = document.createElement('a');
                        var blob = base64Img2Blob(content); //new Blob([content]);
                        //page.compare(blob);
                        var evt = document.createEvent("HTMLEvents");
                        evt.initEvent("click", false, false);//initEvent 不加后两个参数在FF下会报错
                        aLink.download = fileName;
                        aLink.href = URL.createObjectURL(blob);
                        aLink.dispatchEvent(evt);
                    };       
              sayCheese.on('snapshot', function(snapshot) {
                try{
                    var mirror = document.getElementById('mirror');
                    mirror.width = snapshot.width;
                    mirror.height = snapshot.height;
                    var imgData = snapshot.toDataURL('png');
                    mirror.src = imgData;
                    page.vm.show_canvas = true;

                    var filename = page.sd.register.items["account"] + "_" + page.personal_id +"_own.jpg";
                    page._upload(snapshot.toDataURL("image/jpg"),filename,page.sd.host);
                }
                catch(e){
                    console.log(e);
                }
              });
            
              sayCheese.start();
              
              $('#shot').click(function () {
                //console.log(sayCheese);
                try{
                    sayCheese.takeSnapshot();
                }catch(e){
                    return;
                }
              });
        }`)

    _upload: (base64,filename,host) =>
        $(`function() {
            try{
                function sumitImageFile(base64Codes){
                    var form=document.forms[0];
                    var formData = new FormData(form);  
                    formData.append("imageName",convertBase64UrlToBlob(base64Codes),filename);  
                    $.ajax({
                        url : "http://" + host + "/api/upgrade",
                        //url : "http://192.168.2.122:4569/api/upgrade",
                        type : "POST",
                        data : formData,
                        dataType:"text",
                        processData : false,        
                        contentType : false,
                        beforeSend: function(request) {
                            request.setRequestHeader("Test", "Chenxizhang");
                        },
                        success:function(data){
                            //window.location.href="${ctx}"+data;
                            //return (new MessageModal(lang.fileupload.upload_success)).attach();
                        },
                        xhr:function(){            
                            var xhr = new XMLHttpRequest();
                            xhr.upload.addEventListener("progress", function(evt){
                                if (evt.lengthComputable) {
                                    var percentComplete = Math.round(evt.loaded * 100 / evt.total);  
                                    console.log("正在提交."+percentComplete.toString() + '%');        //在控制台打印上传进度
                                }
                            }, false);
                            return xhr;
                        }
                        
                    });
                }
                function convertBase64UrlToBlob(urlData){
                    var bytes=window.atob(urlData.split(',')[1]);       
                    var ab = new ArrayBuffer(bytes.length);
                    var ia = new Uint8Array(ab);
                    for (var i = 0; i < bytes.length; i++) {
                        ia[i] = bytes.charCodeAt(i);
                    }
                    return new Blob( [ab] , {type : 'image/jpeg'});
                }
                sumitImageFile(base64);
            }catch(e){
                console.log(e);
            }
        }`)

    process: (index) =>
        $('#form_wizard').bootstrapWizard(
            rate = (index / 2)
            $('#form_wizard').find('.bar').css({width: rate + '%'})
        )
        if index is 2
            $("#myTab li:eq(1) a").tab "show"
    
class FacePage extends DetailTablePage
    constructor: (@sd) ->
        super "facepage-", "html/facepage.html"
        @dataurl = ""
        @personal_id = ""
        @person_msg = ""

        $(@sd).on "compareresult", (e, result) =>
            if result.name is "compareResult"
                @show_stamp(result.confidence)

    define_vm: (vm) =>
     
        vm.lang = lang.facepage
        vm.get_card = @get_card
        vm.compare = @compare

        vm.personName = ""
        vm.sex = ""
        vm.birthday = ""
        vm.nation = ""
        vm.personId = ""
        vm.address = ""
        vm.startDate = ""
        vm.endDate = ""
        vm.department = ""
        vm.imgPath = ""

        vm.show_card_result = false
        vm.show_canvas = false
        vm_show_compare = false
        vm.show_loading = true
        vm.show_cam = true
        vm.checked = false
        vm.upload_pic = @upload_pic

        vm.show_upload_canvas = false
        vm.compare_result = ""
        vm.show_results = true
        vm.next_action = "读卡"
        vm.camera_error = true
        vm.retry_camera = @retry_camera

    rendered: () =>
        super()
        new WOW().init();
        @webcam(this)
        @vm.show_card_result = false
        @vm.show_canvas = false
        @vm.show_cam = true
        @vm.camera_error = true
        @vm.show_loading = true

        @vm.show_upload_canvas = false
        @initpage(this)
        @vm.compare_result = ""
        @vm.show_results = true
        @vm.next_action = "读卡"
        #$("#show_result_pass").remove();
        @nprocess()
        @auto_Interval()

    nprocess:() =>
        NProgress.start()
        setTimeout (=> NProgress.done();$('.fade').removeClass('out')),500

    initpage: (page) =>
        $(`function() {
            $('#form_wizard_1').bootstrapWizard({
                'nextSelector': '.button-next',
                'previousSelector': '.button-previous',
                onTabClick: function (tab, navigation, index) {
                    //alert('on tab click disabled');
                    return false;
                },
                onNext: function (tab, navigation, index) {
                    var total = navigation.find('li').length;
                    var current = index + 1;
                    $('#form_wizard_1').find('.button-next').show();
                    if (current == 2){
                        page.get_card();
                        return false;
                    }else{
                        if (page.vm.show_canvas == false){
                            $('.alert-error', $('#submit_form')).show();
                            return false;
                        }else{
                            page.compare();
                            $('.alert-error', $('#submit_form')).hide();
                        }
                    }
                    
                    // set wizard title
                    $('.step-title', $('#form_wizard_1')).text('Step ' + (index + 1) + ' of ' + total);
                    // set done steps
                    jQuery('li', $('#form_wizard_1')).removeClass("done");
                    var li_list = navigation.find('li');
                    for (var i = 0; i < index; i++) {
                        jQuery(li_list[i]).addClass("done");
                    }

                    if (current == 1) {
                        $('#form_wizard_1').find('.button-previous').hide();
                    } else {
                        $('#form_wizard_1').find('.button-previous').show();
                    }
                    //console.log(page.vm.show_card_result);
                    if (current >= total) {
                        $('#form_wizard_1').find('.button-next').hide();
                        $('#form_wizard_1').find('.button-submit').show();
                        //displayConfirm();
                    } else {
                        $('#form_wizard_1').find('.button-next').show();
                        $('#form_wizard_1').find('.button-submit').hide();
                    }
                    //App.scrollTo($('.page-title'));
                },
                onPrevious: function (tab, navigation, index) {
                    var total = navigation.find('li').length;
                    var current = index + 1;
                    $('.alert-error', $('#submit_form')).hide();
                    // set wizard title
                    $('.step-title', $('#form_wizard_1')).text('Step ' + (index + 1) + ' of ' + total);
                    // set done steps
                    jQuery('li', $('#form_wizard_1')).removeClass("done");
                    var li_list = navigation.find('li');
                    for (var i = 0; i < index; i++) {
                        jQuery(li_list[i]).addClass("done");
                    }

                    if (current == 1) {
                        $('#form_wizard_1').find('.button-previous').hide();
                        $('#form_wizard_1').find('.button-next').hide();
                        page.vm.next_action = "读卡";
                        page.auto_Interval();
                    } else {
                        page.vm.compare_result = "正在比对.....";
                        //$('#div_result').find("#show_result_pass").hide();
                        var pass = document.getElementById('show_result_pass');
                        var mirror = document.getElementById('mirror');
                        pass.src="";
                        mirror.src = "";
                        page.vm.show_canvas = false;
                        $('#form_wizard_1').find('.button-previous').show();
                    }

                    if (current >= total) {
                        $('#form_wizard_1').find('.button-next').hide();
                        $('#form_wizard_1').find('.button-submit').show();
                    } else {
                        if (current == 1){
                            return;
                        }
                        $('#form_wizard_1').find('.button-next').show();
                        $('#form_wizard_1').find('.button-submit').hide();
                    }

                    //App.scrollTo($('.page-title'));
                },
                onTabShow: function (tab, navigation, index) {
                    var total = navigation.find('li').length;
                    var current = index + 1;
                    var $percent = (current / total) * 100;
                    $('#form_wizard_1').find('.bar').css({
                        width: $percent + '%'
                    });
                }
            });
            $('#form_wizard_1').find('.button-next').hide();
            $('#form_wizard_1').find('.button-previous').hide();
            $('#form_wizard_1 .button-submit').click(function () {
                page.attach();
            }).hide();
        }`)

    retry_camera:() =>
        @webcam(this)

    upload_pic: () =>
        ###
        $.ajax(
            type: 'POST',
            url: 'http://192.168.2.84:8008/api/upload',
            data: '{ "imageData" : "' + @dataurl + '" }',
            contentType: 'application/json; charset=utf-8',
            dataType: 'json',
            success: (msg) ->
                alert("Done, Picture Uploaded.");
        )
        
        query = (new MachineRest('192.168.2.84:8008'))
        machine_detail = query.uploadpic @dataurl
        machine_detail.done (data) =>
            console.log data
        ###

        (new FaceUpLoadModal(@sd, this)).attach()


    auto_Interval:() =>
        @_loop = setInterval((=>
            @get_card()
            ), 1000)
        global_Interval.push @_loop

    get_card: () =>
        ###(new ConfirmModal lang.central_mysql.check, =>
                @frozen()
                chain = new Chain
                chain.chain =>
                    (new MachineRest @sd.host).check ip,name
                chain.chain @sd.update("all")
                show_chain_progress(chain).done =>
                    (new MessageModal (lang.central_mysql.check_success)).attach()
                    @attach()
            ).attach()###
        try
            query = (new MachineRest('localhost:4567'))
            machine_detail = query.get_path '123'
            machine_detail.done (data) =>
                path = data.detail
                query = (new MachineRest('localhost:4567'))
                machine_detail = query.get_card '123'
                machine_detail.done (data) =>
                    if data.status is "success"
                        @person_msg = JSON.stringify(data.detail)
                        @vm.personName = data.detail.personName
                        @vm.sex = data.detail.sex
                        @vm.birthday = data.detail.birthday
                        @vm.nation = data.detail.nation
                        @vm.personId = data.detail.personId
                        @vm.address = data.detail.address
                        @vm.startDate = data.detail.startDate
                        @vm.endDate = data.detail.endDate
                        @vm.department = data.detail.department
                        @vm.imgPath = data.detail.imgPath
                        @vm.show_card_result = true

                        canvas_cards = document.getElementById("canvas_card")
                        cxt= canvas_cards.getContext("2d")

                        $("#myTab li:eq(1) a").tab "show"
                        $("#myTab li:eq(0)").addClass "done"
                        $('#form_wizard_1').find('.button-previous').show()
                        $('#form_wizard_1').find('.button-next').show()
                        $('.alert-error', $('#submit_form')).hide()
                        @vm.next_action = "对比"
                        $('#form_wizard_1').find('.bar').css({
                            width: 66.66 + '%'
                        })

                        img = new Image()
                        img.src=path + '/person.jpg'
                        img.onload = () =>
                            w = Math.min(400, img.width)
                            h = img.height * (w / img.width)
                            canvas_cards.width = w
                            canvas_cards.height = h
                            cxt.drawImage(img,0,0)
                            dataURL = canvas_cards.toDataURL("image/jpg")
                            @personal_id = @vm.personId
                            filename = @sd.register.items["account"] + "_" + @personal_id + "_person.jpg"
                            @_upload(dataURL,filename,@sd.host)

                        clearInterval @_loop if @_loop?

                        #mirror_card = document.getElementById('mirror_card')
                        #mirror_card.src = path + '/person.jpg'
                        #head = document.getElementById('Idcard')
                        #head.src = path + '/person.jpg' 
                        #console.log(dataURL);
                        #console.log(base64);
                        #cardimg = document.getElementById('cardimg')
                        #cardimg.src = path + '/person.jpg'
                        #(new GetcardResultModal(@sd, this, data.detail)).attach()
                        #@process(2)
                    else
                        #@vm.show_card_result = false
                        #$('.alert-error', $('#submit_form')).show()
                        #(new MessageModal(@vm.lang.get_card_error)).attach()
                machine_detail.fail =>
                    @vm.show_card_result = false
                    $('.alert-error', $('#submit_form')).show()
                    (new MessageModal(@vm.lang.get_card_error)).attach()
        catch e
            console.log e
            
    compare: () =>
        try
            ###
            @frozen()
            chain = new Chain
            chain.chain =>
                (new MachineRest 'localhost:4567').compare 'E:\\demo\\own.jpg'
            chain.chain @sd.update("all")
            show_chain_progress(chain).done =>
                query = (new MachineRest('localhost:4567'))
                machine_detail = query.compare 'E:\\demo\\own.jpg'
                machine_detail.done (data) =>
                    if data.status is "success"
                        (new MessageModal(@vm.lang.compare_success(data.detail))).attach()
                    else
                        (new MessageModal(@vm.lang.compare_error)).attach()
                machine_detail.fail =>
                    (new MessageModal(@vm.lang.compare_link_error)).attach()
            @frozen()
            chain = new Chain
            chain.chain =>
                (new MachineRest '192.168.2.84:4567').compare "123"
            chain.chain @sd.update("all")
            show_chain_progress(chain).done =>
                query = (new MachineRest('192.168.2.84:4567'))
                machine_detail = query.compare "123"
                machine_detail.done (data) =>
                    console.log data
                    if data.status is "success"
                        (new MessageModal(@vm.lang.compare_success(data.detail))).attach()
                    else
                        (new MessageModal(@vm.lang.compare_error)).attach()
                machine_detail.fail =>
                    (new MessageModal(@vm.lang.compare_link_error)).attach()
            ###
            ###
            @frozen()
            chain = new Chain
            chain.chain =>
                (new MachineRest @sd.host).compare "123456789",false
            chain.chain @sd.update("all")
            show_chain_progress(chain).done =>
                query = (new MachineRest(@sd.host))
                machine_detail = query.compare @sd.register.items["account"],true
                machine_detail.done (data) =>
                    console.log data
                    @vm.show_results = false
                    pass = document.getElementById('show_result_pass')
                    
                    if data.status is "success"
                        @vm.compare_result = "识别成功,相似度:" + data.detail + "%"
                        $("#show_result_pass").stamper(
                            image : "images/pass.png",
                            scale : 3,
                            speed : 300
                        )
                        #pass.src = "images/pass.png"
                        #(new MessageModal(@vm.lang.compare_success(data.detail))).attach()
                    else
                        #pass.src = "images/failed.png"
                        $("#show_result_pass").stamper(
                            image : "images/failed.png",
                            scale : 3,
                            speed : 300
                        )
                        if data.detail is "remain is 0"
                            @vm.compare_result = "剩余次数不足"
                            #(new MessageModal(@vm.lang.compare_remain_error)).attach()
                        else
                            @vm.compare_result = "识别度过低，请将面部对准摄像头"
                            #(new MessageModal(@vm.lang.compare_error)).attach()

                machine_detail.fail =>
                    (new MessageModal(@vm.lang.compare_link_error)).attach()
                $('#form_wizard_1').find('.button-previous').hide();
            ###

            @frozen()
            chain = new Chain
            chain.chain =>
                (new MachineRest @sd.host).compare @sd.register.items["account"],@personal_id,@person_msg
            chain.chain @sd.update("all"),true
            show_chain_progress(chain).done =>
                console.log 'compare-success'
        catch e
            console.log e
    
    show_stamp: (con) =>
        $('#form_wizard_1').find('.button-previous').hide()
        @vm.show_loading = false
        if parseInt(con) < 50
            @vm.compare_result = "识别度过低,请对准摄像头"
            $("#show_result_pass").stamper(
                image : "images/failed.png",
                scale : 3,
                speed : 300
            )
        else
            @vm.compare_result = "识别成功,相似度为:" + con + "%"
            $("#show_result_pass").stamper(
                image : "images/pass.png",
                scale : 3,
                speed : 300
            )

    getpic: () =>
        query = (new MachineRest('localhost:4567'))
        machine_detail = query.get_pic "123"
        machine_detail.done (data) =>
            console.log(data);
        console.log 123123

    webcam: (page) =>
        $(`function() {
              var sayCheese = new SayCheese('#webcam', { audio: false });
              sayCheese.on('start', function() {
                //console.log(123123000);
                //this.takeSnapshot();
                page.vm.camera_error = false;
              })
              function base64Img2Blob(code){
                        var parts = code.split(';base64,');
                        var contentType = parts[0].split(':')[1];
                        var raw = window.atob(parts[1]);
                        var rawLength = raw.length;

                        var uInt8Array = new Uint8Array(rawLength);

                        for (var i = 0; i < rawLength; ++i) {
                          uInt8Array[i] = raw.charCodeAt(i);
                        }

                        return new Blob([uInt8Array], {type: contentType}); 
                    };
                    function downloadFile(fileName, content){
                       
                        var aLink = document.createElement('a');
                        var blob = base64Img2Blob(content); //new Blob([content]);
                        //page.compare(blob);
                        var evt = document.createEvent("HTMLEvents");
                        evt.initEvent("click", false, false);//initEvent 不加后两个参数在FF下会报错
                        aLink.download = fileName;
                        aLink.href = URL.createObjectURL(blob);
                        aLink.dispatchEvent(evt);
                    };       
              sayCheese.on('snapshot', function(snapshot) {
                try{
                    var mirror = document.getElementById('mirror');
                    mirror.width = snapshot.width;
                    mirror.height = snapshot.height;
                    var imgData = snapshot.toDataURL('png');
                    mirror.src = imgData;
                    page.vm.show_canvas = true;

                    var filename = page.sd.register.items["account"] + "_" + page.personal_id +"_own.jpg";
                    page._upload(snapshot.toDataURL("image/jpg"),filename,page.sd.host);

                    //var mirror_shots = document.getElementById('mirror_shot');
                    //mirror_shots.src = imgData;
                    //var shotimg = document.getElementById('shotimg');
                    //shotimg.width = snapshot.width;
                    //shotimg.height = snapshot.height;
                    //shotimg.src = imgData;
                    //page.dataurl = snapshot.toDataURL('image/png').replace(/^data:image\/(png|jpg);base64,/, "");
                    //page.compare(snapshot.toDataURL("image/jpg"));
                    //sayCheese.stop();
                    //downloadFile('own.jpg', snapshot.toDataURL("image/jpg"));
                    //page.getpic();
                    //console.log(1231238989);
                    //sayCheese.start();
                    //page.vm.show_cam = false;
                    //sayCheese.start();
                    //page.process(3);
                    //console.log(snapshot);
                }
                catch(e){
                    console.log(e);
                }
              });
            
              sayCheese.start();
              
              $('#shot').click(function () {
                //console.log(sayCheese);
                try{
                    sayCheese.takeSnapshot();
                }catch(e){
                    return;
                }
              });
        }`)

    _upload: (base64,filename,host) =>
        $(`function() {
            try{
                function sumitImageFile(base64Codes){
                    var form=document.forms[0];
                    var formData = new FormData(form);  
                    formData.append("imageName",convertBase64UrlToBlob(base64Codes),filename);  
                    $.ajax({
                        url : "http://" + host + "/api/upgrade",
                        //url : "http://192.168.2.122:4569/api/upgrade",
                        type : "POST",
                        data : formData,
                        dataType:"text",
                        processData : false,        
                        contentType : false,
                        beforeSend: function(request) {
                            request.setRequestHeader("Test", "Chenxizhang");
                        },
                        success:function(data){
                            //window.location.href="${ctx}"+data;
                            //return (new MessageModal(lang.fileupload.upload_success)).attach();
                        },
                        xhr:function(){            
                            var xhr = new XMLHttpRequest();
                            xhr.upload.addEventListener("progress", function(evt){
                                if (evt.lengthComputable) {
                                    var percentComplete = Math.round(evt.loaded * 100 / evt.total);  
                                    console.log("正在提交."+percentComplete.toString() + '%');        //在控制台打印上传进度
                                }
                            }, false);
                            return xhr;
                        }
                        
                    });
                }
                function convertBase64UrlToBlob(urlData){
                    var bytes=window.atob(urlData.split(',')[1]);       
                    var ab = new ArrayBuffer(bytes.length);
                    var ia = new Uint8Array(ab);
                    for (var i = 0; i < bytes.length; i++) {
                        ia[i] = bytes.charCodeAt(i);
                    }
                    return new Blob( [ab] , {type : 'image/jpeg'});
                }
                sumitImageFile(base64);
            }catch(e){
                console.log(e);
            }
        }`)

    process: (index) =>
        $('#form_wizard').bootstrapWizard(
            rate = (index / 3)
            $('#form_wizard').find('.bar').css({width: rate + '%'})
        )
        if index is 2
            $("#myTab li:eq(1) a").tab "show"
        if index is 3
            $("#myTab li:eq(2) a").tab "show"

class RegisterPage extends DetailTablePage
    constructor: (@sd,@switch_to_page) ->
        super "userfilepage-", "html/registerpage.html"

        ###$(@sd.register).on "updated", (e, source) =>
            @vm.journal = @subitems()

        $(@sd).on "compareresult", (e, result) =>
            #@vm.journal = @subitems()###

    define_vm: (vm) =>
        vm.lang = lang.register
        vm.journal = @subitems()
        vm.fattr_journal_status = fattr.journal_status
        vm.email = ""
        vm.hotelname=""
        vm.location=""
        vm.realname=""
        vm.remain=""
        vm.tel=""
        vm.userlevel= ""
        vm.user= ""
        vm.summary = ""
        vm.total = ""
        vm.sex = ""
        vm.average = ""
        vm.change_data = @change_data
        vm.change_head = @change_head
        vm.recharge = @recharge
        vm.show_weather = false
        vm.record_detail = @record_detail
        vm.user_name = ""
        vm.amount_compare = 0

        vm.air = ""
        vm.location = ""
        vm.month_day = ""
        vm.week = ""
        vm.old_date = ""
        vm.temp = ""
        vm.day1 = ""
        vm.day2 = ""
        vm.day3 = ""
        vm.city = "深圳市"
        vm.show_weather_animate = false
        vm.switch_to_page = @switch_to_page
        vm.remain = "0"
        vm.userlevel = "0"
        vm.total = "0"
        vm.average = "0"
        vm.user = "加载中.."
        #vm.tip_day1 = "vvv"
        #vm.tip_day2 = "123"

    rendered: () =>
        super()
        #new WOW().init();
        $("#fadein").attr('style', "display:block;");
        $('.tip-twitter').remove();
        $('.anchorBL').remove();
        $('.hastip').poshytip(
            className: 'tip-twitter',
            showTimeout: 1,
            alignTo: 'target',
            alignX: 'center',
            offsetY: 5,
            allowTipHover: false,
            fade: false,
            slide: false
        )
        #@vm.journal = @subitems()
        $scroller = $("#journals-scroller-1")
        $scroller.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true

        $('#slider').nivoSlider(
            effect:"fade",
            animSpeed:100,
            pauseTime:10000
        )
        
        #@location()
        #@calendar()
        #@weather()
        #@update_journal()
        #@data_refresh()
        #@baidu_weather(this)
        #@waves()
        #@fullpage()
        #@scroller()
        @vm.show_weather_animate = false
        @vm.show_weather = false
        @refresh()
        @gaode_maps()
        @datatable_init(this)
        @count_day(this,@sd.pay.items)
        @old_time(this) 
        @nprocess()
        @count_day_amchart(this,@sd.pay.items)
        @baidu_weather(this,@vm.city)
        @avatar()
        
        
    avatar: () =>
        id = @sd.register.items["account"];
        urls = 'http://' + @sd.host + '/downloadAvatar/' + id + '/head/' + id + '_head.jpg';
        #random = Math.random();
        $("#headers").attr('src', urls + "?t=" + random);
        $("#user_img_log").attr('src', urls + "?t=" + random);

    nprocess:() =>
        NProgress.start()
        setTimeout (=> NProgress.done();$('.fade').removeClass('out')),500

    scroller:() =>
        $(window).on "load", () =>
            $(".page-content").mCustomScrollbar();

    fullpage:() =>
        $('#fullpage').fullpage(
            navigation:true,
            navigationPosition:"right",
            navigatinColor:"blue",
            loopBottom:true
        );
        $.fn.fullpage.setAutoScrolling(true);

    waves:() =>
        window.Waves.attach('.wave', ['waves-button', 'waves-float']);
        window.Waves.init();

    data_refresh: ->
        chain = new Chain
        chain.chain @sd.update("pay")
        show_chain_progress(chain).done ->
            console.log "Refresh Registerpage"
        return

    count_day_amchart: (page,items) =>
        $(`function () {
            function Appendzero(obj)  
            {  
                if(obj<10) return "0" +""+ obj;  
                else return obj;  
            }

            var myDate = new Date(); //获取今天日期

            myDate.setDate(myDate.getDate() - 9);
            var dateArray = []; 
            var dateTemp; 
            var total_count = {};
            var average_count = {};
            var flag = 1; 
            var total = [];
            for (var i = 0; i <= 9; i++) {
                dateTemp = (myDate.getFullYear() + '-' + Appendzero(myDate.getMonth()+1)) + "-" + Appendzero(myDate.getDate());
                dateArray.push(dateTemp);
                myDate.setDate(myDate.getDate() + flag);
            }
            for (var i = 0; i < dateArray.length; i++) {
                total_count[dateArray[i]] = 0;
                average_count[dateArray[i]] = 0;
            }   

            Array.prototype.Exists=function(v){
                var b=false;
                for(var i=0;i<this.length;i++){
                    if(this[i]==v){
                        b=true;
                        break;
                    }
                }
                return b;
            }

            for (var i = 0; i < items.length; i++) {
                var strdate = items[i].created.split(" ")[0].split("-")[0] + '-' + items[i].created.split(" ")[0].split("-")[1] + '-' + items[i].created.split(" ")[0].split("-")[2];
                average_count[items[i].created.split(" ")[0]] = average_count[items[i].created.split(" ")[0]] + parseInt(items[i].confidence)
                if ( dateArray.Exists(strdate)) {
                    total_count[strdate] = total_count[strdate] + 1;
                }
            }

            for (var i = 0; i < dateArray.length; i++) {
                total.push(total_count[dateArray[i]]);
                if (total_count[dateArray[i]] !== 0) {
                    average_count[dateArray[i]] = parseInt(average_count[dateArray[i]] / total_count[dateArray[i]]);
                }
            }
            page.grab_data(dateArray,total,average_count)
        }`)
    
    grab_data:(dateArray,total,average_count) =>
        chartdata1 = [{
              "date": "2012-01-01",
              "rate": 227,
              "townName": "New York",
              "townName2": "New York",
              "townSize": 25,
              "average": 40
            }, {
              "date": "2012-01-02",
              "rate": 371,
              "townName": "Washington",
              "townSize": 14,
              "average": 38
            }, {
              "date": "2012-01-03",
              "rate": 433,
              "townName": "Wilmington",
              "townSize": 6,
              "average": 34
            }, {
              "date": "2012-01-04",
              "rate": 345,
              "townName": "Jacksonville",
              "townSize": 7,
              "average": 30
            }, {
              "date": "2012-01-05",
              "rate": 480,
              "townName": "Miami",
              "townName2": "Miami",
              "townSize": 10,
              "average": 25
            }, {
              "date": "2012-01-06",
              "rate": 386,
              "townName": "Tallahassee",
              "townSize": 7,
              "average": 30
            }, {
              "date": "2012-01-07",
              "rate": 348,
              "townName": "New Orleans",
              "townSize": 10,
              "average": 29
            }, {
              "date": "2012-01-08",
              "rate": 238,
              "townName": "Houston",
              "townName2": "Houston",
              "townSize": 16,
              "average": 29
            }, {
              "date": "2012-01-09",
              "rate": 218,
              "townName": "Dalas",
              "townSize": 17,
              "average": 32
            }, {
              "date": "2012-01-10",
              "rate": 349,
              "townName": "Oklahoma City",
              "townSize": 11,
              "average": 35
            }]

        chartdata = []
        for i in [0..dateArray.length - 1]
            chartdata.push {"date":dateArray[i],"rate":total[i],"townName":"","townSize":10,"average":average_count[dateArray[i]]}
        @chart_active(chartdata)

    chart_active: (chartData) =>
        $(`function() {
            /*var chartData = [ {
              "date": "2012-01-01",
              "distance": 227,
              "townName": "New York",
              "townName2": "New York",
              "townSize": 25,
              "latitude": 40
            }, {
              "date": "2012-01-02",
              "distance": 371,
              "townName": "Washington",
              "townSize": 14,
              "latitude": 38
            }, {
              "date": "2012-01-03",
              "distance": 433,
              "townName": "Wilmington",
              "townSize": 6,
              "latitude": 34
            }, {
              "date": "2012-01-04",
              "distance": 345,
              "townName": "Jacksonville",
              "townSize": 7,
              "latitude": 30
            }, {
              "date": "2012-01-05",
              "distance": 480,
              "townName": "Miami",
              "townName2": "Miami",
              "townSize": 10,
              "latitude": 25
            }, {
              "date": "2012-01-06",
              "distance": 386,
              "townName": "Tallahassee",
              "townSize": 7,
              "latitude": 30
            }, {
              "date": "2012-01-07",
              "distance": 348,
              "townName": "New Orleans",
              "townSize": 10,
              "latitude": 29
            }, {
              "date": "2012-01-08",
              "distance": 238,
              "townName": "Houston",
              "townName2": "Houston",
              "townSize": 16,
              "latitude": 29
            }, {
              "date": "2012-01-09",
              "distance": 218,
              "townName": "Dalas",
              "townSize": 17,
              "latitude": 32
            }, {
              "date": "2012-01-10",
              "distance": 349,
              "townName": "Oklahoma City",
              "townSize": 11,
              "latitude": 35
            }, {
              "date": "2012-01-11",
              "distance": 603,
              "townName": "Kansas City",
              "townSize": 10,
              "latitude": 39
            }, {
              "date": "2012-01-12",
              "distance": 534,
              "townName": "Denver",
              "townName2": "Denver",
              "townSize": 18,
              "latitude": 39
            }, {
              "date": "2012-01-13",
              "townName": "Salt Lake City",
              "townSize": 12,
              "distance": 425,
              "latitude": 40,
              "alpha": 0.4
            }, {
              "date": "2012-01-14",
              "latitude": 36,
              "distance": 425,
              "townName": "Las Vegas",
              "townName2": "Las Vegas",
              "bulletClass": "lastBullet"
            }];*/
            var chart = AmCharts.makeChart( "amchart", {

              "type": "serial",
              "theme": "light",
              "fontFamily":"Microsoft YaHei",
              
              "dataDateFormat": "YYYY-MM-DD",
              "dataProvider": chartData,

              "addClassNames": true,
              "startDuration": 1,
              //"color": "#FFFFFF",
              "marginLeft": 0,

              "categoryField": "date",
              "categoryAxis": {
                "parseDates": true,
                "minPeriod": "DD",
                "autoGridCount": false,
                "gridCount": 50,
                "gridAlpha": 0.1,
                "gridColor": "#FFFFFF",
                "axisColor": "#555555",
                "dateFormats": [ {
                  "period": 'DD',
                  "format": 'DD'
                }, {
                  "period": 'WW',
                  "format": 'MMM DD'
                }, {
                  "period": 'MM',
                  "format": 'MMM'
                }, {
                  "period": 'YYYY',
                  "format": 'YYYY'
                } ]
              },

              "valueAxes": [ {
                "id": "a1",
                "title": "对比次数",
                "gridAlpha": 0,
                "axisAlpha": 0
              }, {
                "id": "a2",
                "position": "right",
                "gridAlpha": 0,
                "axisAlpha": 0,
                "labelsEnabled": false
              }],
              "graphs": [ {
                "id": "g1",
                "valueField": "rate",
                "title": "对比次数",
                "type": "column",
                "fillAlphas": 0.9,
                "valueAxis": "a1",
                "balloonText": "[[value]] 次",
                "legendValueText": "[[value]] 次",
                "legendPeriodValueText": "总共: [[value.sum]] 次",
                "lineColor": "rgba(124, 181, 236,0.5)",
                "alphaField": "alpha"
              }, {
                "id": "g2",
                "valueField": "average",
                "classNameField": "bulletClass",
                "title": "平均相似度",
                "type": "line",
                "valueAxis": "a2",
                "lineColor": "rgb(137, 196, 244)",
                "lineThickness": 1,
                "legendValueText": "[[value]] %",
                "descriptionField": "townName",
                "bullet": "round",
                "bulletSizeField": "townSize",
                "bulletBorderColor": "rgb(23, 150, 249)",
                "bulletBorderAlpha": 1,
                "bulletBorderThickness": 3,
                "bulletColor": "rgba(255,255,255,1)",
                "labelText": "[[townName2]]",
                "labelPosition": "right",
                "balloonText": "平均相似度:[[value]] %",
                "showBalloon": true,
                "animationPlayed": true
              }],

              "chartCursor": {
                "zoomable": false,
                "categoryBalloonDateFormat": "DD",
                "cursorAlpha": 0,
                "valueBalloonsEnabled": false
              },
              "legend": {
                "bulletType": "round",
                "equalWidths": false,
                "valueWidth": 120,
                "useGraphSettings": true,
                //"color": "#FFFFFF"
              }
            } );
        }`)

    datatable_init: (page) =>
        $(`function() {
            var table = $("#log-table1").DataTable(dtable_opt({
                /*retrieve: true,
                bSort: false,
                scrollX: true,*/
                destroy:true,
                bProcessing: true,
                bServerSide: true,
                sAjaxSource: "http://" + page.sd.host + "/api/searchRecord",
                aoColumnDefs: [
                  {
                    "aTargets": [0],
                    "mData": null,
                    "bSortable": false,
                    "bSearchable": false,
                    "mRender": function(data, type, full) {
                        return  "<img src=http://" + page.sd.host + "/images" + full[0].replace(" ", "%20") + " style='height: 20px;width: 20px;'>";
                    }
                  }, {
                    "aTargets": [1],
                    "mData": null,
                    "bSortable": false,
                    "bSearchable": false,
                    "mRender": function(data, type, full) {
                        return  "<img src=http://" + page.sd.host + "/images" + full[1].replace(" ", "%20") + " style='height: 20px;width: 20px;'>";
                    }
                  }
                ],
                fnServerData: function(sSource, aoData, fnCallback) {
                  aoData.push({
                    "name": "account",
                    "value": page.sd.register.items["account"]
                  });
                  return $.ajax({
                    "type": 'post',
                    "url": sSource,
                    "dataType": "json",
                    "data": aoData,
                    "success": function(resp) {
                      //page.count_day(page,page.sd.pay.items);
                      try{
                        return fnCallback(resp);
                       }catch(e){
                        return
                       }
                    },
                    "error": function(e) {
                      return console.log('error');
                    }
                  });
                }
            }));
            $(".dataTables_filter input").addClass("m-wrap small");
            $(".dataTables_length select").addClass("m-wrap small");

            $('#log-table1 tbody').on( 'click', 'a', function () {
                var data = table.row( $(this).parents('tr') ).data();
                page.record_detail(data[ 3 ]);
            });
        }`)

    count_day: (page,items) =>
        $(`function () { 
            var myDate = new Date(); //获取今天日期
            myDate.setDate(myDate.getDate() - 9);
            var dateArray = []; 
            var dateTemp; 
            var total_count = {}
            var flag = 1; 
            var total = [];
            page.vm.amount_compare = 0;
            for (var i = 0; i <= 9; i++) {
                dateTemp = (myDate.getMonth()+1)+"月"+myDate.getDate();
                dateArray.push(dateTemp);
                myDate.setDate(myDate.getDate() + flag);
            }
            //var total = [29.9, 71.5, 106.4, 129.2, 144.0, 176.0, 135.6, 148.5, 216.4, 194.1];

            for (var i = 0; i < dateArray.length; i++) {
                total_count[dateArray[i]] = 0;
            }

            Array.prototype.Exists=function(v){
                var b=false;
                for(var i=0;i<this.length;i++){
                    if(this[i]==v){
                        b=true;
                        break;
                    }
                }
                return b;
            }

            for (var i = 0; i < items.length; i++) {
                var strdate = parseInt(items[i].created.split(" ")[0].split("-")[1]) + '月' + parseInt(items[i].created.split(" ")[0].split("-")[2]);
                if ( dateArray.Exists(strdate)) {
                    total_count[strdate] = total_count[strdate] + 1;
                }
            }

            for (var i = 0; i < dateArray.length; i++) {
                page.vm.amount_compare = page.vm.amount_compare + total_count[dateArray[i]];
                total.push(total_count[dateArray[i]]);
            }
            page.day_chart(dateArray,total);
        }`)

    day_chart: (time,total) =>
        $(`function () {
            $('#day_chart').highcharts({
                chart: {
                    type: 'areaspline',
                    marginRight: 10,
                    plotBorderColor:"rgb(255, 255, 255)",
                    plotBorderWidth:1
                },
                title: {
                    text: ''
                },
                subtitle: {
                    text: ''
                },
                exporting: {
                    enabled: false
                },
                credits: {
                    enabled:false
                },
                tooltip: {
                    formatter: function () {
                        return this.x + '<br/>' +
                               '<b>' + this.series.name + ':' +'</b>' + Highcharts.numberFormat(this.y, 0);
                    },
                    style: {
                        color:'#fff',
                        fontSize:'12px',
                        opacity:0.8,
                        fontFamily:"Microsoft Yahei"
                    },
                    borderRadius:0,
                    borderColor:'#000',
                    backgroundColor:'#000'
                },
                xAxis: {
                    categories: time,
                    labels:{
                        style: { 
                            "fontFamily": "Microsoft Yahei" 
                        }
                    }
                },
                yAxis: {
                    title: {
                        text: ''
                    },
                    min:-1,
                    tickColor:"rgba(0,0,0,0)",
                    tickWidth: 0,
                    gridLineColor: 'rgba(0,0,0,0)',
                    labels:{
                        enabled:false
                    }
                },
                plotOptions: {
                    areaspline: {
                        threshold: null,
                        states: {
                            hover: {
                                lineWidth: 2
                            }
                        },
                        fillOpacity: 0.2,
                        marker: {
                            enabled: true,
                            symbol: 'circle',
                            radius: 5.0,
                            lineWidth: 3,
                            lineColor: "#1796f9",
                            fillColor:"#fff",
                            states: {
                                hover: {
                                    enabled: true
                                }
                            }
                        },
                        lineWidth: 2
                    }
                },
                series: [{
                    name: '对比次数',
                    data: total,
                    showInLegend: false
                }]
            });
        }`);

    baidu_weather:(page,city) =>
        if (window.XMLHttpRequest)
            xhr=new XMLHttpRequest();  
        else
            xhr=new ActiveXObject("Microsoft.XMLHTTP");
        xhr.open('get','http://api.map.baidu.com/telematics/v3/weather?location=' + city + '&output=json&ak=SGlfxoEEgdtmV60T195lr7BYx6bFLvkI',true);
        xhr.send(null);
        xhr.onreadystatechange = () =>  
            try
                if xhr.readyState is 4 or xhr.readyState is 200 
                    respon = $.parseJSON(xhr.responseText);    
                    
                    #空气质量
                    air_con = parseInt(respon.results[0].pm25);
                    if (0 <= air_con and air_con< 35)
                        @vm.air = "优";
                    else if (35 <= air_con and air_con < 75)
                       @vm.air = "良";
                    else if (75 <= air_con and air_con < 115)
                       @vm.air = "轻度污染";
                    else if (115 <= air_con and air_con < 150)
                       @vm.air = "中度污染";
                    else if (150 <= air_con and air_con < 250)
                       @vm.air = "重度污染";
                    else
                       @vm.air = "严重污染";
                    
                    @vm.day1 = respon.results[0].weather_data[1].date;
                    @vm.day2 = respon.results[0].weather_data[2].date;
                    @vm.day3 = respon.results[0].weather_data[3].date;
                    @vm.temp = respon.results[0].weather_data[0].temperature;

                    # skycons 
                    skycons = new Skycons({"color": "rgb(22, 158, 244)"});

                    count = 0
                    for i in respon.results[0].weather_data
                        staus = i.weather;
                        idx = 'day' + count + '_weather';
                        count = count + 1
                        if ( staus.indexOf("晴") >= 0 )
                            skycons.add(document.getElementById(idx), Skycons.CLEAR_DAY);
                        else if (staus.indexOf("云") >= 0 )
                           skycons.add(document.getElementById(idx), Skycons.CLOUDY);
                        else if (staus.indexOf("雹") >= 0 )
                           skycons.add(document.getElementById(idx), Skycons.SLEET);
                        else if (staus.indexOf("雪") >= 0 )
                           skycons.add(document.getElementById(idx), Skycons.SNOW);
                        else if (staus.indexOf("雾") >= 0 )
                           skycons.add(document.getElementById(idx), Skycons.FOG);
                        else
                           skycons.add(document.getElementById(idx), Skycons.RAIN);
                    skycons.play();
            catch e
                console.log e
                return

    old_time:(page) =>
        $(`function() {
            function getCurrentDateTime() { 
                var d = new Date(); 
                var year = d.getFullYear(); 
                var month = d.getMonth() + 1; 
                var date = d.getDate(); 
                var week = d.getDay(); 
                /*时分秒*/
                /*var hours = d.getHours(); 
                var minutes = d.getMinutes(); 
                var seconds = d.getSeconds(); 
                var ms = d.getMilliseconds();*/
                var curDateTime = year; 
                if (month > 9) 
                curDateTime = curDateTime + "年" + month; 
                else
                curDateTime = curDateTime + "年0" + month; 
                if (date > 9) 
                curDateTime = curDateTime + "月" + date + "日"; 
                else
                curDateTime = curDateTime + "月0" + date + "日"; 
                /*if (hours > 9) 
                curDateTime = curDateTime + " " + hours; 
                else 
                curDateTime = curDateTime + " 0" + hours; 
                if (minutes > 9) 
                curDateTime = curDateTime + ":" + minutes; 
                else 
                curDateTime = curDateTime + ":0" + minutes; 
                if (seconds > 9) 
                curDateTime = curDateTime + ":" + seconds; 
                else 
                curDateTime = curDateTime + ":0" + seconds;*/
                var weekday = ""; 
                if (week == 0) 
                weekday = "周日"; 
                else if (week == 1) 
                weekday = "周一"; 
                else if (week == 2) 
                weekday = "周二"; 
                else if (week == 3) 
                weekday = "周三"; 
                else if (week == 4) 
                weekday = "周四"; 
                else if (week == 5) 
                weekday = "周五"; 
                else if (week == 6) 
                weekday = "周六"; 
                curDateTime = curDateTime + " " + weekday; 
                return curDateTime; 
            }
            /*获取当前农历*/
            function showCal(){ 
                var D=new Date(); 
                var yy=D.getFullYear(); 
                var mm=D.getMonth()+1; 
                var dd=D.getDate(); 
                var ww=D.getDay(); 
                var ss=parseInt(D.getTime() / 1000); 
                if (yy<100) yy="19"+yy; 
                    return GetLunarDay(yy,mm,dd); 
                } 
                 
                //定义全局变量 
                var CalendarData=new Array(100); 
                var madd=new Array(12); 
                var tgString="甲乙丙丁戊己庚辛壬癸"; 
                var dzString="子丑寅卯辰巳午未申酉戌亥"; 
                var numString="一二三四五六七八九十"; 
                var monString="正二三四五六七八九十冬腊"; 
                var weekString="日一二三四五六"; 
                var sx="鼠牛虎兔龙蛇马羊猴鸡狗猪"; 
                var cYear,cMonth,cDay,TheDate; 
                CalendarData = new Array(0xA4B,0x5164B,0x6A5,0x6D4,0x415B5,0x2B6,0x957,0x2092F,0x497,0x60C96,0xD4A,0xEA5,0x50DA9,0x5AD,0x2B6,0x3126E, 0x92E,0x7192D,0xC95,0xD4A,0x61B4A,0xB55,0x56A,0x4155B, 0x25D,0x92D,0x2192B,0xA95,0x71695,0x6CA,0xB55,0x50AB5,0x4DA,0xA5B,0x30A57,0x52B,0x8152A,0xE95,0x6AA,0x615AA,0xAB5,0x4B6,0x414AE,0xA57,0x526,0x31D26,0xD95,0x70B55,0x56A,0x96D,0x5095D,0x4AD,0xA4D,0x41A4D,0xD25,0x81AA5,0xB54,0xB6A,0x612DA,0x95B,0x49B,0x41497,0xA4B,0xA164B, 0x6A5,0x6D4,0x615B4,0xAB6,0x957,0x5092F,0x497,0x64B, 0x30D4A,0xEA5,0x80D65,0x5AC,0xAB6,0x5126D,0x92E,0xC96,0x41A95,0xD4A,0xDA5,0x20B55,0x56A,0x7155B,0x25D,0x92D,0x5192B,0xA95,0xB4A,0x416AA,0xAD5,0x90AB5,0x4BA,0xA5B, 0x60A57,0x52B,0xA93,0x40E95); 
                madd[0]=0; 
                madd[1]=31; 
                madd[2]=59; 
                madd[3]=90; 
                madd[4]=120; 
                madd[5]=151; 
                madd[6]=181; 
                madd[7]=212; 
                madd[8]=243; 
                madd[9]=273; 
                madd[10]=304; 
                madd[11]=334; 
                 
                function GetBit(m,n){ 
                return (m>>n)&1; 
                } 
                //农历转换 
                function e2c(){ 
                TheDate= (arguments.length!=3) ? new Date() : new Date(arguments[0],arguments[1],arguments[2]); 
                var total,m,n,k; 
                var isEnd=false; 
                var tmp=TheDate.getYear(); 
                if(tmp<1900){ 
                tmp+=1900; 
                } 
                total=(tmp-1921)*365+Math.floor((tmp-1921)/4)+madd[TheDate.getMonth()]+TheDate.getDate()-38; 
                 
                if(TheDate.getYear()%4==0&&TheDate.getMonth()>1) { 
                total++; 
                } 
                for(m=0;;m++){ 
                k=(CalendarData[m]<0xfff)?11:12; 
                for(n=k;n>=0;n--){ 
                if(total<=29+GetBit(CalendarData[m],n)){ 
                isEnd=true; break; 
                } 
                total=total-29-GetBit(CalendarData[m],n); 
                } 
                if(isEnd) break; 
                } 
                cYear=1921 + m; 
                cMonth=k-n+1; 
                cDay=total; 
                if(k==12){ 
                if(cMonth==Math.floor(CalendarData[m]/0x10000)+1){ 
                cMonth=1-cMonth; 
                } 
                if(cMonth>Math.floor(CalendarData[m]/0x10000)+1){ 
                cMonth--; 
                } 
                } 
                } 
                 
                function GetcDateString(){ 
                var tmp=""; 
                /*显示农历年：（ 如：甲午(马)年 ）*/
                /*tmp+=tgString.charAt((cYear-4)%10); 
                tmp+=dzString.charAt((cYear-4)%12); 
                tmp+="("; 
                tmp+=sx.charAt((cYear-4)%12); 
                tmp+=")年 ";*/
                if(cMonth<1){ 
                tmp+="(闰)"; 
                tmp+=monString.charAt(-cMonth-1); 
                }else{ 
                tmp+=monString.charAt(cMonth-1); 
                } 
                tmp+="月"; 
                tmp+=(cDay<11)?"初":((cDay<20)?"十":((cDay<30)?"廿":"三十")); 
                if (cDay%10!=0||cDay==10){ 
                tmp+=numString.charAt((cDay-1)%10); 
                } 
                return tmp; 
                } 
                 
                function GetLunarDay(solarYear,solarMonth,solarDay){ 
                //solarYear = solarYear<1900?(1900+solarYear):solarYear; 
                if(solarYear<1921 || solarYear>2020){ 
                return ""; 
                }else{ 
                solarMonth = (parseInt(solarMonth)>0) ? (solarMonth-1) : 11; 
                e2c(solarYear,solarMonth,solarDay); 
                return GetcDateString(); 
                } 
            }
            var date = getCurrentDateTime(); 
            var calendar = showCal(); 
            page.vm.month_day = date.split(" ")[0];
            page.vm.week = date.split(" ")[1];
            page.vm.old_date = calendar;
        }`)

    update_journal:() =>
        $(document).ready(`function() {
            try{
                var xhr;  
                if (window.XMLHttpRequest){  
                    xhr=new XMLHttpRequest();  
                }else{  
                    xhr=new ActiveXObject("Microsoft.XMLHTTP");  
                }
                var id = page.sd.register.items["account"];
                xhr.open('get','http://' + page.sd.host + '/api/getRecord/' + id ,true);
                xhr.send(null);
                xhr.onreadystatechange = function(){  
                    if(xhr.readyState==4 || xhr.readyState==200){
                        console.log(JSON.parse(xhr.responseText));  
                    }  
                }
            }catch(e){
                console.log('error');
            }
        }`)

    refresh: () =>
        @vm.email = @sd.register.items["email"]
        @vm.hotelname = @sd.register.items["hotelname"]
        @vm.location = @sd.register.items["location"]
        @vm.realname = @sd.register.items["realname"]
        @vm.remain = @sd.register.items["remain"]
        @vm.tel = @sd.register.items["tel"]
        @vm.userlevel = @sd.register.items["userlevel"]
        @vm.user = @sd.register.items["user"]
        @vm.total = @sd.register.items["total"]
        @vm.sex = @sd.register.items["sex"]
        @vm.average = @sd.register.items["average"]
        
        if @vm.hotelname is ""
            @vm.hotelname = "请填写"

        if @vm.location is ""
            @vm.location = "请填写"

        if @vm.realname is ""
            @vm.realname = "请填写"

        if @vm.tel is ""
            @vm.tel = "请填写"

        if @vm.sex is ""
            @vm.sex = "请填写"

        if @vm.user is ""
            @vm.user = "请填写"

    subitems: () =>
        try
            @sd.pay.items.reverse()
        catch e
            return []

    record_detail:(uid) =>
        (new RegisterRecordModal(@sd, this,uid)).attach()

    recharge: () =>
        (new RegisterRechargeModal(@sd, this)).attach()

    weather:() =>
        $(`function() {
          $.simpleWeather({
            location: '广东, 深圳',
            woeid: '',
            unit: 'c',
            success: function(weather) {
              html = '<h2><i class="icon-'+weather.code+'"></i> '+weather.temp+'&deg;'+weather.units.temp+'</h2>';
              html += '<ul><li>'+weather.city+', '+weather.region+'</li>';
              html += '<li class="currently">'+weather.currently+'</li>';
              //html += '<li>'+weather.wind.direction+' '+weather.wind.speed+' '+weather.units.speed+'</li></ul>';
          
              $("#_weather").html(html);
            },
            error: function(error) {
              $("#_weather").html('<p>'+error+'</p>');
            }
          });
        }`);

    calendar: () =>
        $(document).ready(`function() {
            $('#_calendar').clndr({
              template: $('#_calendar').html(),
              events: [
                { date: '2013-09-09', title: 'CLNDR GitHub Page Finished', url: 'http://github.com/kylestetz/CLNDR' }
              ],
              clickEvents: {
                click: function(target) {
                  console.log(target);
                },
                onMonthChange: function(month) {
                  console.log('you just went to ' + month.format('MMMM, YYYY'));
                }
              },
              doneRendering: function() {
                console.log('this would be a fine place to attach custom event handlers.');
              }
            });
        }`);

    location: () =>
        longitude = 113.8875210000
        latitude = 22.5533490000
        @maps(longitude,latitude)

    gaode_maps:() =>
        try
            map = new AMap.Map('allmap', {
                resizeEnable: true
            });

            map.plugin 'AMap.Geolocation', () =>
                geolocation = new AMap.Geolocation({
                    enableHighAccuracy: true, #是否使用高精度定位，默认:true
                    timeout: 10000,          #超过10秒后停止定位，默认：无穷大
                    buttonOffset: new AMap.Pixel(10, 20),#定位按钮与设置的停靠位置的偏移量，默认：Pixel(10, 20)
                    zoomToAccuracy: true,      #定位成功后调整地图视野范围使定位位置及精度范围视野内可见，默认：false
                    buttonPosition:'RB'
                });
                map.addControl(geolocation);
                geolocation.getCurrentPosition();

                AMap.event.addListener(geolocation, 'complete', (data) =>
                    try
                        @vm.city = data.addressComponent.city;
                        #@baidu_weather(this,@vm.city);
                    catch e
                        console.log e
                        return
                )

                AMap.event.addListener(geolocation, 'error', (data) => 
                    try
                        console.log data
                        return (new MessageModal(lang.register.map_error)).attach(); 
                    catch e
                        console.log e
                        return
                )
        catch e
            console.log e
            return (new MessageModal(lang.register.map_error)).attach(); 

    baidu_maps_new: () =>
        try
            map = new BMap.Map("allmap");    #创建Map实例
            map.centerAndZoom(new BMap.Point(116.331398,39.897445),11);
            map.enableScrollWheelZoom(true);     #开启鼠标滚轮缩放
            $('.anchorBL').remove();

            keyword = @sd.register.items["location"] + @sd.register.items["hotelname"];
            urls = "http://api.map.baidu.com/geocoder/v2/?address=" + keyword + "&output=json&ak=SGlfxoEEgdtmV60T195lr7BYx6bFLvkI"
            xhr=new XMLHttpRequest();  
            xhr.open('get',urls ,true);
            xhr.send(null);
            xhr.onreadystatechange = () =>  
                output = $.parseJSON(xhr.responseText);
                if output isnt null
                    map.clearOverlays();
                    new_point = new BMap.Point(output.result.location.lng,output.result.location.lat);
                    marker = new BMap.Marker(new_point); 
                    map.addOverlay(marker);             
                    map.panTo(new_point);
                    @baidu_weather(this,@vm.city);
                    return
        catch e
            console.log e
            return (new MessageModal(lang.register.map_error)).attach();

    baidu_maps_old: (page) =>
        $(`function() {
            try{
                var map = new BMap.Map("allmap");    // 创建Map实例
                map.centerAndZoom(new BMap.Point(116.404, 39.915), 11);  // 初始化地图,设置中心点坐标和地图级别
                map.addControl(new BMap.MapTypeControl());   //添加地图类型控件
                map.setCurrentCity("深圳");          // 设置地图显示的城市 此项是必须设置的
                map.enableScrollWheelZoom(true);     //开启鼠标滚轮缩放
                
                // 用经纬度设置地图中心点
                map.clearOverlays();//清空原来的标注
                var keyword = page.sd.register.items["location"] + page.sd.register.items["hotelname"];
                
                var localSearch = new BMap.LocalSearch(map);
                localSearch.enableAutoViewport(); //允许自动调节窗体大小

                localSearch.setSearchCompleteCallback(function (searchResult) {
                    try{
                        var poi = searchResult.getPoi(0);
                        map.centerAndZoom(poi.point, 10);
                        var marker = new BMap.Marker(new BMap.Point(poi.point.lng, poi.point.lat));  // 创建标注，为要查询的地方对应的经纬度
                        map.addOverlay(marker);

                        //var infoWindow = new BMap.InfoWindow("<p style='font-size:14px;'>" + content + "</p>");
                        //marker.addEventListener("click", function () { this.openInfoWindow(infoWindow); });
                    }catch(e){
                        return (new MessageModal(lang.register.address_error)).attach();
                    }

                });
                $('.anchorBL').remove();
                if (keyword !== ""){
                    localSearch.search(keyword);
                }
                //setTimeout(function(){
                    //map.setZoom(20);   
                //}, 2000);  //2秒后放大到14级
                

                function myFun(result){
                    var cityName = result.name;
                    map.setCenter(cityName);
                    page.vm.city = cityName;
                }
                var myCity = new BMap.LocalCity();
                myCity.get(myFun);
                //page.baidu_weather(page,page.vm.city);
                
                /*$('#relocate').click(function () {
                    var geolocation = new BMap.Geolocation();
                    geolocation.getCurrentPosition(function(r){
                        if(this.getStatus() == BMAP_STATUS_SUCCESS){
                            //var mk = new BMap.Marker(r.point);
                            //map.addOverlay(mk);
                            //map.panTo(r.point);

                            function initdata(){ //页面初始化
                                if (navigator.geolocation){
                                    navigator.geolocation.getCurrentPosition(showPosition,showError);//HTML5获取GPS设备地理位置信息
                                }else{
                                    document.getElementById("allmap").innerHTML="Geolocation is not supported by this browser.";
                                }
                            }
                            function showPosition(position){
                                var x=position.coords.latitude;//获取纬度
                                var y=position.coords.longitude;//获取经度
                                //转为百度地图坐标
                                //注意点：1、coords的经度、纬度顺序（可多组坐标转换，以；（分号）隔开）。2、from与to的准确性。3、callback为回调函数
                                var positionUrl = "http://api.map.baidu.com/geoconv/v1/?coords="+y+","+x+"&from=1&to=5&ak=SGlfxoEEgdtmV60T195lr7BYx6bFLvkI&callback=getMap";
                                var script = document.createElement('script');
                                script.src = positionUrl;
                                document.getElementsByTagName("head")[0].appendChild(script);
                            }
                            function getMap(data){
                                //返回的状态码，0为正常；1为内部错误；21为from非法；22为to非法；24为coords格式非法；25为coords个数非法，超过限制 
                                if(data.status!=0){
                                    alert("地图坐标转换出错");
                                    return ;
                                }
                                //result为数组
                                var result = data.result;
                                var lon = result[0].x;//经度
                                var lat = result[0].y;//纬度
                                                                                                                        
                                // 百度地图API功能
                                var point = new BMap.Point(lon,lat);
                                map.centerAndZoom(point, 14);
                                var marker1 = new BMap.Marker(point);  // 创建标注
                                map.addOverlay(marker1);              // 将标注添加到地图中
                                //创建信息窗口
                                var infoWindow1 = new BMap.InfoWindow("您当前所处的位置,经度:"+lon+";纬度:"+lat);
                                marker1.addEventListener("click", function(){this.openInfoWindow(infoWindow1);});
                            }
                            //HTML5获取地理位置信息错误处理
                            function showError(error)
                            {
                                switch(error.code)
                                  {
                                  case error.PERMISSION_DENIED:
                                    document.getElementById("allmap").innerHTML="User denied the request for Geolocation."
                                    break;
                                  case error.POSITION_UNAVAILABLE:
                                    document.getElementById("allmap").innerHTML="Location information is unavailable."
                                    break;
                                  case error.TIMEOUT:
                                    document.getElementById("allmap").innerHTML="The request to get user location timed out."
                                    break;
                                  case error.UNKNOWN_ERROR:
                                    document.getElementById("allmap").innerHTML="An unknown error occurred."
                                    break;
                                  }
                            }
                            //alert('您的位置：'+r.point.lng+','+r.point.lat);
                        }
                        else {
                            alert('failed'+this.getStatus());
                        }        
                    },{enableHighAccuracy: true})
                });*/

            }catch(e){
                return (new MessageModal(lang.register.map_error)).attach();
            }
        }`)

    change_head: () =>
        #(new RegisterChangeHeaderModal(@sd, this)).attach()
        (new RegisterChangeHeadModal(@sd, this)).attach()

    change_data: () =>
        (new RegisterChangeDataModal(@sd, this)).attach()

    subitems_journal: () =>
        arrays = [{"date":"2016/09/07 08:45:37","level":"info","chinese_message":"用户 Ace 完成了一次充值"},\
                  {"date":"2016/09/07 08:45:37","level":"critical","chinese_message":"用户 Ace 完成了一次充值"},\
                  {"date":"2016/09/07 08:45:37","level":"critical","chinese_message":"用户 Ace 完成了一次充值"},\
                  {"date":"2016/09/07 08:45:37","level":"warning","chinese_message":"用户 Ace 完成了一次对比"},\
                  {"date":"2016/09/07 08:45:37","level":"info","chinese_message":"用户 Ace 已欠费"},\
                  {"date":"2016/09/07 08:45:37","level":"info","chinese_message":"用户 Ace 完成了一次充值"},\
                  {"date":"2016/09/07 08:45:37","level":"info","chinese_message":"用户 Ace 完成了一次充值"},\
                  {"date":"2016/09/07 08:45:37","level":"warning","chinese_message":"用户 Ace 完成了一次充值"},\
                  {"date":"2016/09/07 08:45:37","level":"info","chinese_message":"用户 Ace 完成了一次充值"},\
                  {"date":"2016/09/07 08:45:37","level":"warning","chinese_message":"用户 Ace 完成了一次充值"}]
        arrays

class PreCountPage extends DetailTablePage
    constructor: (@sd) ->
        super "countpage-", "html/pre_countpage.html"

    define_vm: (vm) =>
        vm.lang = lang.precountpage
        vm.rendered = @rendered
        vm.search_data = @search_data
        vm._start = ""
        vm._end = ""
        vm.option_camera = @option_camera()
        vm.show_search = true

    rendered: () =>
        super()
        new WOW().init();
        $('.datepicker').remove()
        $("#camera").chosen()
        @vm.option_camera = @option_camera()
        @datepicker()
        @vm.show_search = true
        @nprocess()

    nprocess:() =>
        NProgress.start()
        setTimeout (=> NProgress.done();$('.fade').removeClass('out')),500

    datepicker:() =>
        $(`function() {
            var nowTemp = new Date();
            var now = new Date(nowTemp.getFullYear(), nowTemp.getMonth(), nowTemp.getDate(), 0, 0, 0, 0);
            var checkin = $('#start_time').fdatepicker({
                /*
                onRender: function (date) {
                    return date.valueOf() < now.valueOf() ? 'disabled' : '';
                }
                */
            }).on('changeDate', function (ev) {
                if (ev.date.valueOf() > checkout.date.valueOf()) {
                    var newDate = new Date(ev.date)
                    newDate.setDate(newDate.getDate() + 1);
                    checkout.update(newDate);
                }
                checkin.hide();
                $('#end_time')[0].focus();
            }).data('datepicker');
            var checkout = $('#end_time').fdatepicker({
                onRender: function (date) {
                    return date.valueOf() <= checkin.date.valueOf() ? 'disabled' : '';
                }
            }).on('changeDate', function (ev) {
                checkout.hide();
            }).data('datepicker');
        }`)
        
    search_data:() =>
        NProgress.start()
        start_Time = $('#start_time').val()
        end_Time = $('#end_time').val()
        selected_camera = $("#camera").val()

        if selected_camera is "no" or start_Time is "" or end_Time is ""
            (new MessageModal(@vm.lang.no_select)).attach()
            return

        startstamp = (Date.parse(new Date(start_Time)))/1000
        endstamp = ((Date.parse(new Date(end_Time)))/1000) + 86400

        if  startstamp >= endstamp
            (new MessageModal(@vm.lang.time_error)).attach()
            return

        @_search(this,selected_camera,startstamp,endstamp)
        #(new CountPage(@sd, this, [],start_Time,end_Time,startstamp,endstamp)).attach();
        @vm.show_search = false
        
    _search:(page,ipc,start,end) =>
        $(`function() {
            $.ajax({
                url: "http://192.168.2.122:8012/api/chart?start=" + start + "&end=" + end ,
                type:'GET',
                dataType: "json",
                success:function(data){
                    NProgress.done();
                    if ( data.num_age.length == 0){
                        page.vm.show_search = true;
                        return (new MessageModal(lang.precountpage.no_data)).attach();
                    }else{
                        page.goto_count_server(data,start,end);
                    }
                },
                error : function() {
                    NProgress.done();
                    page.vm.show_search = true;
                    return (new MessageModal(lang.precountpage.search_error)).attach();
                }
            })
        }`)
        ###$(`function() {
            try{
                $.ajax({
                    url : "http://192.168.2.82:8012/api/statistics",
                    type : "POST",
                    data : {"start":1451581261000,"end":1577811661000},
                    dataType:"json",
                    success:function(data){
                        console.log(data);
                        if ( !data.aaData.length){
                            page.vm.show_search = true;
                            return (new MessageModal(lang.precountpage.no_data)).attach();
                        }else{
                            page.goto_count(data.aaData,start,end);
                        }
                    }
                });
            }catch(e){
                console.log(e);
            }
        }`)
        ###

    goto_count_server: (_data,start_stamp,end_stamp) =>      
        start_Time = $('#start_time').val()
        end_Time = $('#end_time').val()
        (new CountPage(@sd, this, _data,start_Time,end_Time,start_stamp,end_stamp)).attach();
       
    goto_count: (_data,start_stamp,end_stamp) =>
        tmp = []
        try
            for i in _data
                i.sex = i[1]
                i.age = i[2]
                i.time = i[3]
                tmp.push {"age":i.age,"sex":i.sex,"time":i.time,"ipc":1}
            start_Time = $('#start_time').val()
            end_Time = $('#end_time').val()
            (new CountPage(@sd, this, tmp,start_Time,end_Time,start_stamp,end_stamp)).attach();
        catch e
            console.log e
        
    option_camera: () =>
        options = [{key:"请选择",value:"no"},{key:"1",value:"1"},{key:"2",value:"2"},{key:"3",value:"3"},{key:"4",value:"4"},{key:"5",value:"5"}]
        options

class CountPage extends DetailTablePage
    constructor: (@sd,@page,@_stat,@start,@end,@start_stamp,@end_stamp) ->
        super "countpage-", "html/countpage.html"

    define_vm: (vm) =>
        vm.lang = lang.register
        #vm.journal = @_stat
        vm.location_local = ""
        vm.ipc = 1
        vm.start = @start
        vm.end = @end
        vm.location = "深圳春茧体育馆"
        vm.journal = []
        vm.total_data = ""
        vm.calculate_sex = ""
        vm.calculate_age = ""
        vm.unit_age = "岁"
        vm.rechoose = @rechoose

    rendered: () =>
        super()
        new WOW().init();

        @vm.total_data = 0
        #@vm.journal = @_stat
        @datatable_init(this)

        $scroller = $("#journals-scroller-1")
        $scroller.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true

        #@chart1()
        #@chart_real()
        @maps(this,@vm.location)
        #@search_result(this,@camera,@start,@end)
        #@strtime()

        @chart_server()
        #@nprocess()

    rechoose:() =>
        (new PreCountPage(@sd,this)).attach();

    nprocess:() =>
        NProgress.start()
        setTimeout (=> NProgress.done();$('.fade').removeClass('out')),500

    datatable_init: (page) =>
        $("#log-table1").dataTable dtable_opt(
            #retrieve: true, 
            #bSort: false,
            #scrollX: true, 
            bProcessing: true,
            bServerSide: true,
            destroy:true,
            sAjaxSource:"http://192.168.2.122:8012/api/statistics",
            aoColumnDefs: [
                "aTargets": [0],
                "mData": null,
                "bSortable": false,
                "bSearchable": false,
                "mRender": (data, type, full) ->
                    if full[0] is 'N/A'
                        return  "<img src='images/user-error.png' style='height: 30px;width: 30px;'>"
                    else
                        return  "<img src=" + "http://192.168.2.122:8012/" + full[0] + " style='height: 30px;border-radius: 30px !important;width: 30px;'>"
            ],
            fnServerData: (sSource, aoData, fnCallback)->
                aoData.push({"name":"ipc","value":page.vm.ipc});
                aoData.push({"name":"begin","value":page.start_stamp});
                aoData.push({"name":"end","value":page.end_stamp});
                $.ajax({
                    "type" : 'post',
                    "url" : sSource,
                    "dataType" : "json",
                    "data" : aoData,
                    "success" : (resp)->
                        try
                            console.log(resp);
                            page.vm.total_data = resp.iTotalDisplayRecords;
                            fnCallback(resp);
                        catch e
                            return
                    "error":(e) ->
                       console.log(e.message);
                })
        )
        
        $(".dataTables_filter input").addClass "m-wrap small"
        $(".dataTables_length select").addClass "m-wrap small"

    strtime: () =>
        @vm.start = new Date(@start).toLocaleString()
        @vm.end = new Date(@end).toLocaleString()

    search_result:(page,ipc,start,end) =>
       $(`function() {
            var xhr;  
            if (window.XMLHttpRequest){  
                xhr=new XMLHttpRequest();  
            }else{  
                xhr=new ActiveXObject("Microsoft.XMLHTTP");  
            }
            xhr.open('get','http://192.168.2.84:7000/api/statistics/?query=ipc:' + ipc + '&limit=1000' + '&begin=' + start + '&end=' + end ,true);
            xhr.send(null);
            xhr.onreadystatechange = function(){  
                if(xhr.readyState==4 || xhr.readyState==200){
                    page._count =  xhr.responseText;
                    //console.log(xhr.responseText);  
                }  
            }
        }`)

    subitems: () =>
        temp = [{"age":"2","sex":"男","time":"9:00-12:00"},{"age":"22","sex":"女","time":"3:00-6:00"},{"age":"12","sex":"男","time":"6:00-9:00"},{"age":"11","sex":"男","time":"9:00-12:00"},{"age":"42","sex":"女","time":"12:00-15:00"},{"age":"18","sex":"女","time":"15:00-18:00"},{"age":"52","sex":"女","time":"18:00-21:00"},{"age":"55","sex":"女","time":"21:00-24:00"},{"age":"2","sex":"男","time":"0:00-3:00"},{"age":"22","sex":"女","time":"3:00-6:00"},{"age":"12","sex":"男","time":"6:00-9:00"},{"age":"11","sex":"男","time":"9:00-12:00"},{"age":"42","sex":"女","time":"12:00-15:00"},{"age":"18","sex":"女","time":"15:00-18:00"},{"age":"52","sex":"男","time":"18:00-21:00"},{"age":"55","sex":"女","time":"21:00-24:00"},{"age":"2","sex":"男","time":"0:00-3:00"},{"age":"22","sex":"女","time":"3:00-6:00"},{"age":"12","sex":"男","time":"6:00-9:00"},{"age":"11","sex":"男","time":"9:00-12:00"},{"age":"42","sex":"女","time":"12:00-15:00"},{"age":"18","sex":"女","time":"15:00-18:00"},{"age":"52","sex":"男","time":"18:00-21:00"},{"age":"55","sex":"女","time":"21:00-24:00"},{"age":"2","sex":"男","time":"9:00-12:00"},{"age":"22","sex":"女","time":"3:00-6:00"},{"age":"12","sex":"女","time":"6:00-9:00"},{"age":"11","sex":"男","time":"9:00-12:00"},{"age":"42","sex":"女","time":"12:00-15:00"},{"age":"18","sex":"女","time":"15:00-18:00"},{"age":"52","sex":"男","time":"18:00-21:00"},{"age":"55","sex":"女","time":"21:00-24:00"},{"age":"2","sex":"男","time":"0:00-3:00"},{"age":"22","sex":"女","time":"3:00-6:00"},{"age":"12","sex":"男","time":"6:00-9:00"},{"age":"11","sex":"女","time":"9:00-12:00"},{"age":"42","sex":"女","time":"12:00-15:00"},{"age":"18","sex":"女","time":"15:00-18:00"},{"age":"52","sex":"女","time":"18:00-21:00"},{"age":"55","sex":"女","time":"21:00-24:00"},{"age":"2","sex":"男","time":"0:00-3:00"},{"age":"22","sex":"女","time":"3:00-6:00"},{"age":"12","sex":"女","time":"6:00-9:00"},{"age":"11","sex":"男","time":"9:00-12:00"},{"age":"42","sex":"女","time":"12:00-15:00"},{"age":"18","sex":"女","time":"15:00-18:00"},{"age":"52","sex":"男","time":"18:00-21:00"},{"age":"55","sex":"女","time":"21:00-24:00"},{"age":"2","sex":"男","time":"0:00-3:00"},{"age":"22","sex":"女","time":"3:00-6:00"},{"age":"12","sex":"男","time":"6:00-9:00"},{"age":"11","sex":"男","time":"9:00-12:00"},{"age":"42","sex":"女","time":"12:00-15:00"},{"age":"18","sex":"女","time":"15:00-18:00"},{"age":"52","sex":"男","time":"18:00-21:00"},{"age":"55","sex":"女","time":"21:00-24:00"},{"age":"2","sex":"男","time":"0:00-3:00"},{"age":"22","sex":"女","time":"3:00-6:00"},{"age":"12","sex":"女","time":"6:00-9:00"},{"age":"11","sex":"男","time":"9:00-12:00"},{"age":"42","sex":"女","time":"12:00-15:00"},{"age":"18","sex":"女","time":"15:00-18:00"},{"age":"52","sex":"男","time":"18:00-21:00"},{"age":"55","sex":"女","time":"21:00-24:00"},{"age":"2","sex":"男","time":"0:00-3:00"},{"age":"22","sex":"女","time":"3:00-6:00"},{"age":"12","sex":"男","time":"6:00-9:00"},{"age":"11","sex":"男","time":"9:00-12:00"},{"age":"42","sex":"女","time":"12:00-15:00"},{"age":"18","sex":"女","time":"15:00-18:00"},{"age":"52","sex":"男","time":"18:00-21:00"},{"age":"55","sex":"女","time":"21:00-24:00"},{"age":"2","sex":"男","time":"0:00-3:00"},{"age":"22","sex":"女","time":"3:00-6:00"},{"age":"12","sex":"男","time":"6:00-9:00"},{"age":"11","sex":"男","time":"9:00-12:00"},{"age":"42","sex":"女","time":"12:00-15:00"},{"age":"18","sex":"女","time":"15:00-18:00"},{"age":"52","sex":"男","time":"18:00-21:00"},{"age":"55","sex":"女","time":"21:00-24:00"},{"age":"2","sex":"男","time":"0:00-3:00"},{"age":"22","sex":"女","time":"3:00-6:00"},{"age":"12","sex":"男","time":"6:00-9:00"},{"age":"11","sex":"男","time":"9:00-12:00"},{"age":"42","sex":"女","time":"12:00-15:00"},{"age":"18","sex":"女","time":"15:00-18:00"},{"age":"52","sex":"男","time":"18:00-21:00"},{"age":"55","sex":"女","time":"21:00-24:00"},{"age":"2","sex":"男","time":"0:00-3:00"},{"age":"22","sex":"女","time":"3:00-6:00"},{"age":"12","sex":"女","time":"6:00-9:00"},{"age":"11","sex":"女","time":"9:00-12:00"},{"age":"42","sex":"女","time":"12:00-15:00"},{"age":"18","sex":"女","time":"15:00-18:00"},{"age":"52","sex":"男","time":"18:00-21:00"},{"age":"55","sex":"女","time":"21:00-24:00"},{"age":"2","sex":"男","time":"0:00-3:00"},{"age":"22","sex":"女","time":"3:00-6:00"},{"age":"12","sex":"男","time":"6:00-9:00"},{"age":"11","sex":"男","time":"9:00-12:00"},{"age":"42","sex":"女","time":"12:00-15:00"},{"age":"18","sex":"女","time":"15:00-18:00"},{"age":"52","sex":"男","time":"18:00-21:00"},{"age":"55","sex":"女","time":"21:00-24:00"},{"age":"2","sex":"男","time":"0:00-3:00"},{"age":"22","sex":"女","time":"3:00-6:00"},{"age":"12","sex":"男","time":"6:00-9:00"},{"age":"11","sex":"女","time":"9:00-12:00"},{"age":"42","sex":"女","time":"12:00-15:00"},{"age":"18","sex":"女","time":"15:00-18:00"},{"age":"52","sex":"男","time":"18:00-21:00"},{"age":"55","sex":"女","time":"21:00-24:00"},{"age":"2","sex":"男","time":"0:00-3:00"},{"age":"22","sex":"女","time":"3:00-6:00"},{"age":"12","sex":"男","time":"6:00-9:00"},{"age":"11","sex":"男","time":"9:00-12:00"},{"age":"42","sex":"女","time":"12:00-15:00"},{"age":"18","sex":"女","time":"15:00-18:00"},{"age":"52","sex":"男","time":"18:00-21:00"},{"age":"55","sex":"女","time":"21:00-24:00"},{"age":"2","sex":"男","time":"0:00-3:00"},{"age":"22","sex":"女","time":"3:00-6:00"},{"age":"12","sex":"男","time":"6:00-9:00"},{"age":"11","sex":"男","time":"9:00-12:00"},{"age":"42","sex":"女","time":"12:00-15:00"},{"age":"18","sex":"女","time":"15:00-18:00"},{"age":"52","sex":"男","time":"18:00-21:00"},{"age":"55","sex":"女","time":"21:00-24:00"},{"age":"2","sex":"男","time":"0:00-3:00"},{"age":"22","sex":"女","time":"3:00-6:00"},{"age":"12","sex":"男","time":"6:00-9:00"},{"age":"11","sex":"男","time":"9:00-12:00"},{"age":"42","sex":"女","time":"12:00-15:00"},{"age":"18","sex":"女","time":"15:00-18:00"},{"age":"52","sex":"男","time":"18:00-21:00"},{"age":"55","sex":"女","time":"21:00-24:00"},{"age":"2","sex":"男","time":"0:00-3:00"},{"age":"22","sex":"女","time":"3:00-6:00"},{"age":"12","sex":"男","time":"6:00-9:00"},{"age":"11","sex":"男","time":"9:00-12:00"},{"age":"42","sex":"女","time":"12:00-15:00"},{"age":"18","sex":"女","time":"15:00-18:00"},{"age":"52","sex":"男","time":"18:00-21:00"},{"age":"55","sex":"女","time":"21:00-24:00"},{"age":"2","sex":"男","time":"0:00-3:00"},{"age":"22","sex":"女","time":"3:00-6:00"},{"age":"12","sex":"男","time":"6:00-9:00"},{"age":"11","sex":"男","time":"9:00-12:00"},{"age":"42","sex":"女","time":"12:00-15:00"},{"age":"18","sex":"女","time":"15:00-18:00"},{"age":"52","sex":"女","time":"18:00-21:00"},{"age":"55","sex":"女","time":"21:00-24:00"},{"age":"2","sex":"男","time":"0:00-3:00"},{"age":"22","sex":"女","time":"3:00-6:00"},{"age":"12","sex":"男","time":"6:00-9:00"},{"age":"11","sex":"男","time":"9:00-12:00"},{"age":"42","sex":"女","time":"12:00-15:00"},{"age":"18","sex":"女","time":"15:00-18:00"},{"age":"52","sex":"男","time":"18:00-21:00"},{"age":"55","sex":"女","time":"21:00-24:00"},{"age":"11","sex":"男","time":"9:00-12:00"},{"age":"11","sex":"男","time":"9:00-12:00"},{"age":"11","sex":"男","time":"9:00-12:00"},{"age":"11","sex":"男","time":"9:00-12:00"},{"age":"11","sex":"男","time":"9:00-12:00"},{"age":"11","sex":"男","time":"9:00-12:00"},{"age":"11","sex":"男","time":"9:00-12:00"},{"age":"11","sex":"男","time":"9:00-12:00"},{"age":"11","sex":"男","time":"9:00-12:00"},{"age":"11","sex":"男","time":"9:00-12:00"},{"age":"11","sex":"男","time":"9:00-12:00"},{"age":"11","sex":"男","time":"9:00-12:00"},{"age":"11","sex":"男","time":"9:00-12:00"},{"age":"11","sex":"男","time":"9:00-12:00"},{"age":"11","sex":"男","time":"9:00-12:00"},{"age":"11","sex":"男","time":"9:00-12:00"},{"age":"11","sex":"男","time":"9:00-12:00"},{"age":"11","sex":"男","time":"6:00-9:00"},{"age":"11","sex":"男","time":"6:00-9:00"},{"age":"11","sex":"男","time":"6:00-9:00"},{"age":"11","sex":"男","time":"6:00-9:00"},{"age":"11","sex":"男","time":"6:00-9:00"},{"age":"11","sex":"男","time":"6:00-9:00"},{"age":"11","sex":"男","time":"6:00-9:00"},{"age":"11","sex":"男","time":"12:00-15:00"},{"age":"11","sex":"男","time":"12:00-15:00"},{"age":"11","sex":"男","time":"12:00-15:00"},{"age":"11","sex":"男","time":"12:00-15:00"},{"age":"11","sex":"男","time":"12:00-15:00"},{"age":"11","sex":"男","time":"12:00-15:00"},{"age":"11","sex":"男","time":"3:00-6:00"},{"age":"11","sex":"男","time":"3:00-6:00"},{"age":"11","sex":"男","time":"3:00-6:00"},{"age":"11","sex":"男","time":"3:00-6:00"},{"age":"11","sex":"男","time":"15:00-18:00"},{"age":"11","sex":"男","time":"15:00-18:00"},{"age":"11","sex":"男","time":"15:00-18:00"},{"age":"11","sex":"男","time":"15:00-18:00"},{"age":"11","sex":"男","time":"15:00-18:00"}]
        return temp

    subitems_time:() =>
        tmp  = [{"age":"12","sex":"男","time":"2014-07-10 0:21:12"},{"age":"11","sex":"女","time":"2014-07-10 0:25:12"},{"age":"27","sex":"男","time":"2014-07-10 0:56:12"},{"age":"21","sex":"女","time":"2014-07-10 0:05:12"},{"age":"24","sex":"女","time":"2014-07-10 1:15:12"},{"age":"51","sex":"男","time":"2014-07-10 0:25:12"},{"age":"43","sex":"男","time":"2014-07-10 1:21:12"},{"age":"11","sex":"女","time":"2014-07-10 1:25:12"},{"age":"21","sex":"男","time":"2014-07-10 1:56:12"},{"age":"21","sex":"女","time":"2014-07-10 1:05:12"},{"age":"61","sex":"女","time":"2014-07-10 1:15:12"},{"age":"51","sex":"男","time":"2014-07-10 1:25:12"},{"age":"43","sex":"男","time":"2014-07-10 2:21:12"},{"age":"11","sex":"女","time":"2014-07-10 2:25:12"},{"age":"21","sex":"男","time":"2014-07-10 2:56:12"},{"age":"21","sex":"女","time":"2014-07-10 2:05:12"},{"age":"61","sex":"女","time":"2014-07-10 2:15:12"},{"age":"51","sex":"男","time":"2014-07-10 2:25:12"},{"age":"43","sex":"男","time":"2014-07-10 3:21:12"},{"age":"11","sex":"女","time":"2014-07-10 3:25:12"},{"age":"25","sex":"男","time":"2014-07-10 3:56:12"},{"age":"21","sex":"女","time":"2014-07-10 3:05:12"},{"age":"61","sex":"女","time":"2014-07-10 3:15:12"},{"age":"51","sex":"男","time":"2014-07-10 3:25:12"},{"age":"26","sex":"男","time":"2014-07-10 4:21:12"},{"age":"11","sex":"女","time":"2014-07-10 4:25:12"},{"age":"21","sex":"男","time":"2014-07-10 4:56:12"},{"age":"21","sex":"女","time":"2014-07-10 4:05:12"},{"age":"61","sex":"女","time":"2014-07-10 4:15:12"},{"age":"51","sex":"男","time":"2014-07-10 4:25:12"},{"age":"29","sex":"男","time":"2014-07-10 5:21:12"},{"age":"11","sex":"女","time":"2014-07-10 5:25:12"},{"age":"21","sex":"男","time":"2014-07-10 5:56:12"},{"age":"21","sex":"女","time":"2014-07-10 5:05:12"},{"age":"61","sex":"女","time":"2014-07-10 5:15:12"},{"age":"51","sex":"男","time":"2014-07-10 5:25:12"},{"age":"4","sex":"男","time":"2014-07-10 6:21:12"},{"age":"11","sex":"女","time":"2014-07-10 6:25:12"},{"age":"21","sex":"男","time":"2014-07-10 6:56:12"},{"age":"15","sex":"女","time":"2014-07-10 6:05:12"},{"age":"61","sex":"女","time":"2014-07-10 6:15:12"},{"age":"51","sex":"男","time":"2014-07-10 6:25:12"},{"age":"1","sex":"男","time":"2014-07-10 7:21:12"},{"age":"12","sex":"女","time":"2014-07-10 7:25:12"},{"age":"21","sex":"男","time":"2014-07-10 7:56:12"},{"age":"18","sex":"女","time":"2014-07-10 7:05:12"},{"age":"51","sex":"女","time":"2014-07-10 7:15:12"},{"age":"11","sex":"男","time":"2014-07-10 7:25:12"},{"age":"23","sex":"男","time":"2014-07-10 8:21:12"},{"age":"81","sex":"女","time":"2014-07-10 8:25:12"},{"age":"21","sex":"男","time":"2014-07-10 8:56:12"},{"age":"41","sex":"女","time":"2014-07-10 8:05:12"},{"age":"61","sex":"女","time":"2014-07-10 8:15:12"},{"age":"51","sex":"男","time":"2014-07-10 9:25:12"},{"age":"43","sex":"男","time":"2014-07-10 9:21:12"},{"age":"21","sex":"女","time":"2014-07-10 9:25:12"},{"age":"21","sex":"男","time":"2014-07-10 9:56:12"},{"age":"21","sex":"女","time":"2014-07-10 9:05:12"},{"age":"10","sex":"女","time":"2014-07-10 9:15:12"},{"age":"21","sex":"男","time":"2014-07-10 10:25:12"},{"age":"23","sex":"男","time":"2014-07-10 11:21:12"},{"age":"11","sex":"女","time":"2014-07-10 10:25:12"},{"age":"21","sex":"男","time":"2014-07-10 11:56:12"},{"age":"21","sex":"女","time":"2014-07-10 10:05:12"},{"age":"61","sex":"女","time":"2014-07-10 11:15:12"},{"age":"21","sex":"男","time":"2014-07-10 11:25:12"},{"age":"43","sex":"男","time":"2014-07-10 12:21:12"},{"age":"11","sex":"女","time":"2014-07-10 11:25:12"},{"age":"21","sex":"男","time":"2014-07-10 12:56:12"},{"age":"21","sex":"女","time":"2014-07-10 11:05:12"},{"age":"29","sex":"女","time":"2014-07-10 12:15:12"},{"age":"51","sex":"男","time":"2014-07-10 12:25:12"},{"age":"43","sex":"男","time":"2014-07-10 13:21:12"},{"age":"11","sex":"女","time":"2014-07-10 13:25:12"},{"age":"21","sex":"男","time":"2014-07-10 13:56:12"},{"age":"21","sex":"女","time":"2014-07-10 13:05:12"},{"age":"61","sex":"女","time":"2014-07-10 13:15:12"},{"age":"5","sex":"男","time":"2014-07-10 13:25:12"},{"age":"43","sex":"男","time":"2014-07-10 14:21:12"},{"age":"11","sex":"女","time":"2014-07-10 14:25:12"},{"age":"21","sex":"男","time":"2014-07-10 14:56:12"},{"age":"6","sex":"女","time":"2014-07-10 14:05:12"},{"age":"61","sex":"女","time":"2014-07-10 14:15:12"},{"age":"51","sex":"男","time":"2014-07-10 14:25:12"},{"age":"43","sex":"男","time":"2014-07-10 15:21:12"},{"age":"11","sex":"女","time":"2014-07-10 15:25:12"},{"age":"21","sex":"男","time":"2014-07-10 15:56:12"},{"age":"21","sex":"女","time":"2014-07-10 15:05:12"},{"age":"61","sex":"女","time":"2014-07-10 15:15:12"},{"age":"38","sex":"男","time":"2014-07-10 15:25:12"},{"age":"43","sex":"男","time":"2014-07-10 16:21:12"},{"age":"11","sex":"女","time":"2014-07-10 16:25:12"},{"age":"21","sex":"男","time":"2014-07-10 16:56:12"},{"age":"21","sex":"女","time":"2014-07-10 16:05:12"},{"age":"61","sex":"女","time":"2014-07-10 16:15:12"},{"age":"51","sex":"男","time":"2014-07-10 16:25:12"},{"age":"43","sex":"男","time":"2014-07-10 17:21:12"},{"age":"11","sex":"女","time":"2014-07-10 17:25:12"},{"age":"21","sex":"男","time":"2014-07-10 17:56:12"},{"age":"21","sex":"女","time":"2014-07-10 17:05:12"},{"age":"31","sex":"女","time":"2014-07-10 17:15:12"},{"age":"51","sex":"男","time":"2014-07-10 17:25:12"},{"age":"33","sex":"男","time":"2014-07-10 18:21:12"},{"age":"11","sex":"女","time":"2014-07-10 18:25:12"},{"age":"21","sex":"男","time":"2014-07-10 18:56:12"},{"age":"21","sex":"女","time":"2014-07-10 18:05:12"},{"age":"36","sex":"女","time":"2014-07-10 18:15:12"},{"age":"31","sex":"男","time":"2014-07-10 18:25:12"},{"age":"43","sex":"男","time":"2014-07-10 19:21:12"},{"age":"11","sex":"女","time":"2014-07-10 19:25:12"},{"age":"21","sex":"男","time":"2014-07-10 19:56:12"},{"age":"21","sex":"女","time":"2014-07-10 19:05:12"},{"age":"61","sex":"女","time":"2014-07-10 19:15:12"},{"age":"51","sex":"男","time":"2014-07-10 19:25:12"},{"age":"43","sex":"男","time":"2014-07-10 20:21:12"},{"age":"11","sex":"女","time":"2014-07-10 20:25:12"},{"age":"21","sex":"男","time":"2014-07-10 20:56:12"},{"age":"21","sex":"女","time":"2014-07-10 20:05:12"},{"age":"41","sex":"女","time":"2014-07-10 20:15:12"},{"age":"51","sex":"男","time":"2014-07-10 20:25:12"},{"age":"43","sex":"男","time":"2014-07-10 21:21:12"},{"age":"11","sex":"女","time":"2014-07-10 21:25:12"},{"age":"21","sex":"男","time":"2014-07-10 21:56:12"},{"age":"21","sex":"女","time":"2014-07-10 21:05:12"},{"age":"61","sex":"女","time":"2014-07-10 21:15:12"},{"age":"19","sex":"男","time":"2014-07-10 21:25:12"},{"age":"3","sex":"男","time":"2014-07-10 22:21:12"},{"age":"12","sex":"女","time":"2014-07-10 22:25:12"},{"age":"21","sex":"男","time":"2014-07-10 22:56:12"},{"age":"21","sex":"女","time":"2014-07-10 22:05:12"},{"age":"33","sex":"女","time":"2014-07-10 22:15:12"},{"age":"51","sex":"男","time":"2014-07-10 22:25:12"},{"age":"43","sex":"男","time":"2014-07-10 23:21:12"},{"age":"11","sex":"女","time":"2014-07-10 23:25:12"},{"age":"21","sex":"男","time":"2014-07-10 23:56:12"},{"age":"1","sex":"女","time":"2014-07-10 23:05:12"},{"age":"39","sex":"女","time":"2014-07-10 23:15:12"},{"age":"51","sex":"男","time":"2014-07-10 23:25:12"}]

        tmp

    maps: (page,location) =>
        $(`function() {
            try{
                var map = new BMap.Map("allmap");    // 创建Map实例
                map.centerAndZoom(new BMap.Point(116.404, 39.915), 11);  // 初始化地图,设置中心点坐标和地图级别
                map.addControl(new BMap.MapTypeControl());   //添加地图类型控件
                map.setCurrentCity("深圳");          // 设置地图显示的城市 此项是必须设置的
                map.enableScrollWheelZoom(true);     //开启鼠标滚轮缩放
                
                // 用经纬度设置地图中心点
                map.clearOverlays();//清空原来的标注
                var keyword = location;
                //page.vm.location_local = keyword;
                var localSearch = new BMap.LocalSearch(map);
                localSearch.enableAutoViewport(); //允许自动调节窗体大小

                localSearch.setSearchCompleteCallback(function (searchResult) {
                    var poi = searchResult.getPoi(0);
                    map.centerAndZoom(poi.point, 20);
                    var marker = new BMap.Marker(new BMap.Point(poi.point.lng, poi.point.lat));  // 创建标注，为要查询的地方对应的经纬度
                    map.addOverlay(marker);

                    //var infoWindow = new BMap.InfoWindow("<p style='font-size:14px;'>" + content + "</p>");
                    //marker.addEventListener("click", function () { this.openInfoWindow(infoWindow); });

                });
                $('.anchorBL').remove();
                if (keyword !== ""){
                    localSearch.search(keyword);
                }
                //setTimeout(function(){
                    //map.setZoom(20);   
                //}, 2000);  //2秒后放大到14级
                
            }catch(e){
                return (new MessageModal(lang.register.map_error)).attach();
            }
        }`)

    getArrItem:(arr, num) =>
        #数组随机选取num个元素
        temp_array = new Array();
        for index in arr
            temp_array.push(index);
        return_array = new Array();

        for i in [0..num]
            if temp_array.length > 0
                arrIndex = Math.floor(Math.random() * temp_array.length);
                return_array[i] = temp_array[arrIndex];
                temp_array.splice(arrIndex, 1);
            else 
                break;
        return return_array;

    chart_server:() =>
        collect_age = []
        num_male = @_stat.num_male
        num_female = @_stat.num_female
        num = @_stat.num
        total_male = @_stat.total_male
        total_female = @_stat.total_female
        num_xy_male = @_stat.num_xy_male
        num_xy_female = @_stat.num_xy_female
        num_age = @_stat.num_age

        #性别最大值
        if num_male > num_female
            @vm.calculate_sex = "男"
        else
            @vm.calculate_sex = "女"

        #年龄最大值
        for i in num_age
            collect_age.push i[1]
        max = Math.max.apply(null,collect_age)

        for i in num_age
            if i[1] is max
                @vm.calculate_age = i[0]
                if i[0] is "99以上"
                    @vm.calculate_age = "99"
                    @vm.unit_age = "以上"


        #散点图
        xy_male = @getArrItem(num_xy_male,100)
        xy_female = @getArrItem(num_xy_female,100)
        for i in xy_male
            i[0] = i[0]*1000

        for i in xy_female
            i[0] = i[0]*1000
        
        try
            @load1(num_male,num_female) #性别人流量对比
            @load2(num) #人流总数
            @load3(num) #条形图
            @load4(total_male,total_female) #性别比例
            #@load6() #蜘蛛图
            @load7(num_age) #年龄比例
            @load5(xy_male,xy_female) #散点图
            #@load5(num_xy_male,num_xy_female) #散点图
        catch e
            console.log e

    chart_real:() =>
        base =  @_stat
        dist_age = {}
        num_male = 0
        num_female = 0
        num_age = []
        collect_age = []

        ####性别饼图#####

        for i in base
            if i.sex is "男"
                num_male = num_male + 1
            else
                num_female = num_female + 1
        if num_male > num_female
            @vm.calculate_sex = "男"
        else
            @vm.calculate_sex = "女"

        @load4(num_male,num_female)

        ####年龄3D饼图####
        ages = ['1-9','10-19','20-29','30-39','40-49','50-59','60-69','70-79','80-89','90-99','99以上']
        for i in ages
            dist_age[i] = 0

        for i in base
            if 1 <= parseInt(i.age) <=9
                dist_age['1-9'] = dist_age['1-9'] + 1
            else if 10 <= parseInt(i.age) <=19
                dist_age['10-19'] = dist_age['10-19'] + 1
            else if 20 <= parseInt(i.age) <=29
                dist_age['20-29'] = dist_age['20-29'] + 1
            else if 30 <= parseInt(i.age) <=39
                dist_age['30-39'] = dist_age['30-39'] + 1
            else if 40 <= parseInt(i.age) <=49
                dist_age['40-49'] = dist_age['40-49'] + 1
            else if 50 <= parseInt(i.age) <=59
                dist_age['50-59'] = dist_age['50-59'] + 1
            else if 60 <= parseInt(i.age) <=69
                dist_age['60-69'] = dist_age['60-69'] + 1
            else if 70 <= parseInt(i.age) <=79
                dist_age['70-79'] = dist_age['70-79'] + 1
            else if 80 <= parseInt(i.age) <=89
                dist_age['80-89'] = dist_age['80-89'] + 1
            else if 90 <= parseInt(i.age) <=99
                dist_age['90-99'] = dist_age['90-99'] + 1
            else
                dist_age['99以上'] = dist_age['99以上'] + 1

        for i in ages
            xy = []
            xy.push i
            xy.push dist_age[i]
            collect_age.push dist_age[i]
            if dist_age[i] isnt 0
                num_age.push xy

        max = Math.max.apply(null,collect_age)

        for i in ages
            if dist_age[i] is max
                @vm.calculate_age = i
                if i is "99以上"
                    @vm.calculate_age = "99"
                    @vm.unit_age = "以上"

        @load7(num_age)

    chart1:() =>
        dist = {}
        dist_male = {}
        dist_female = {}
        dist_age = {}

        num = []
        num_male = []
        num_female = []
        num_age = []

        num_xy_male = []
        num_xy_female = []

        total_male = 0
        total_female = 0

        times = ['0:00-3:00','3:00-6:00','6:00-9:00','9:00-12:00','12:00-15:00','15:00-18:00','18:00-21:00','21:00-24:00']
        ages = ['1-9','10-19','20-29','30-39','40-49','50-59','60-69','70-79','80-89','90-99']
        sexs= ['male','female']

        total = @subitems()
        total_time = @subitems_time()
        
        for i in times
            dist[i] = 0
            dist_male[i] = 0
            dist_female[i] = 0

        for i in ages
            dist_age[i] = 0

        for i in total
            dist[i.time] = dist[i.time] + 1
            if i.sex is "男"
                dist_male[i.time] = dist_male[i.time] + 1
            else
                dist_female[i.time] = dist_female[i.time] + 1
            if 1 <= parseInt(i.age) <=9
                dist_age['1-9'] = dist_age['1-9'] + 1
            else if 10 <= parseInt(i.age) <=19
                dist_age['10-19'] = dist_age['10-19'] + 1
            else if 20 <= parseInt(i.age) <=29
                dist_age['20-29'] = dist_age['20-29'] + 1
            else if 30 <= parseInt(i.age) <=39
                dist_age['30-39'] = dist_age['30-39'] + 1
            else if 40 <= parseInt(i.age) <=49
                dist_age['40-49'] = dist_age['40-49'] + 1
            else if 50 <= parseInt(i.age) <=59
                dist_age['50-59'] = dist_age['50-59'] + 1
            else if 60 <= parseInt(i.age) <=69
                dist_age['60-69'] = dist_age['60-69'] + 1
            else if 70 <= parseInt(i.age) <=79
                dist_age['70-79'] = dist_age['70-79'] + 1
            else if 80 <= parseInt(i.age) <=89
                dist_age['80-89'] = dist_age['80-89'] + 1
            else
                dist_age['90-99'] = dist_age['90-99'] + 1

        for i in ages
            xy = []
            xy.push i
            xy.push dist_age[i]
            if dist_age[i] isnt 0
                num_age.push xy

        for i in times
            num.push dist[i]
            num_male.push dist_male[i]
            num_female.push dist_female[i]

        for i in num_male
            total_male = total_male + i
        for i in num_female
            total_female = total_female + i
        
        for i in total_time
            xy = []
            timestamp2 = Date.parse(new Date(i.time))
            timestamp2 = timestamp2 / 1000
            xy.push parseInt(timestamp2)
            xy.push parseInt(i.age)
            if i.sex is "男"
                num_xy_male.push xy
            else
                num_xy_female.push xy
        
        @load1(num_male,num_female)
        @load2(num)
        @load3(num)
        @load4(total_male,total_female)
        @load5(num_xy_male,num_xy_female)
        #@load6()
        @load7(num_age)

    load1: (male,female) =>
        $(`function () {
            $('#chart1').highcharts({
                chart:{
                  type:"spline"
                },
                title: {
                    text: '',
                    x: -20 //center
                },
                subtitle: {
                    text: '',
                    x: -20
                },
                xAxis: {
                    categories: ['0:00-3:00','3:00-6:00','6:00-9:00','9:00-12:00','12:00-15:00','15:00-18:00','18:00-21:00','21:00-24:00']

                },
                credits: {
                      enabled: false
                },
                exporting: {
                      enabled: false
                },
                yAxis: {
                    title: {
                        text: '人数',
                        style:{
                            fontFamily:'Microsoft Yahei'
                        }
                    },
                    plotLines: [{
                        value: 0,
                        width: 1,
                        color: '#808080'
                    }]
                },
                tooltip: {
                    valueSuffix: '人',
                    style: {
                        color:'#fff',
                        fontSize:'12px',
                        opacity:0.8,
                        fontFamily:'Microsoft Yahei'
                    },
                    borderRadius:0,
                    borderColor:'#000',
                    backgroundColor:'#000'
                },
                legend: {
                    layout: 'vertical',
                    align: 'right',
                    verticalAlign: 'middle',
                    borderWidth: 0
                },
                series: [{
                    name: '男',
                    data: male
                }, {
                    name: '女',
                    data: female
                }]
            });
        }`);
    
    load2: (num) =>
        $(`function () {
            $(document).ready(function () {
                Highcharts.setOptions({
                    global: {
                        useUTC: false
                    }
                });
                $('#chart2').highcharts({
                    chart: {
                      type: 'column'
                    },
                    title: {
                      text: ''
                    },
                    subtitle: {
                      text: ''
                    },
                    credits: {
                      enabled: false
                    },
                    exporting: {
                      enabled: false
                    },
                    legend: {
                      enabled: true,
                      backgroundColor: '#FFFFFF',
                      floating: true,
                      align: 'right',
                      layout: 'vertical',
                      verticalAlign: 'top',
                      itemStyle: {
                        color: 'rgb(110,110,110)',
                        fontWeight: '100',
                        fontFamily: "Microsoft YaHei"
                      }
                    },
                    xAxis: {
                      crosshair: true,
                      categories: ['0:00-3:00','3:00-6:00','6:00-9:00','9:00-12:00','12:00-15:00','15:00-18:00','18:00-21:00','21:00-24:00']
                    },
                    yAxis: {
                      min: 0,
                      title: {
                        text: '总人数',
                        style:{
                            fontFamily:'Microsoft Yahei'
                        }
                      }
                    },
                    tooltip: {
                      //headerFormat: '<span style="font-size:10px">{point.key}</span><table>',
                      pointFormat: '<tr><td style="color:{series.color};padding:0"></td>' + '<td style="padding:0"><b>{point.y}人 </b></td></tr>',
                      footerFormat: '</table>',
                      shared: true,
                      useHTML: true,
                      style: {
                        color: '#fff',
                        fontSize: '12px',
                        opacity: 0.8,
                        fontFamily:'Microsoft Yahei'
                      },
                      borderRadius: 0,
                      borderColor: '#000',
                      backgroundColor: '#000'
                    },
                    plotOptions: {
                      column: {
                        animation: false,
                        //pointPadding: 0.2,
                        borderWidth: 0,
                        color: 'rgba(60, 192, 150,0.2)',
                        borderColor: 'rgb(60, 192, 150)',
                        borderWidth: 1,
                        //pointPadding: 0,
                        events: {
                          legendItemClick: function() {
                            return false;
                          },
                          click: function(event) {}
                        }
                      }
                    },
                    series: [
                      {
                        name: '总人数',
                        data: num
                      }
                    ]
                });
            });
        }`)

    load3: (num) =>
        $(`function () {
            $('#chart3').highcharts({
                chart: {
                    polar: true
                },
                title: {
                    text: ''
                },
                pane: {
                    startAngle: 0,
                    endAngle: 360
                },
                credits: {
                      enabled: false
                },
                exporting: {
                  enabled: false
                },
                xAxis: {
                    tickInterval: 3,
                    min: 0,
                    max: 24,
                    labels: {
                        formatter: function () {
                            return this.value + ':00';
                        }
                    }
                },
                yAxis: {
                    min: 0,
                    max:50
                },
                legend: {
                    enabled: true
                },
                plotOptions: {
                    series: {
                        pointStart: 0,
                        pointInterval: 45
                    },
                    column: {
                        pointPadding: 0,
                        groupPadding: 0
                    }
                },
                series: [ {
                    type: 'area',
                    name: '人数',
                    data:  num
                }]
            });
        }`);

    load4:(male,female) =>
        $(`function () {
            $('#chart4').highcharts({
                chart: {
                    plotBackgroundColor: null,
                    plotBorderWidth: null,
                    plotShadow: false
                },
                title: {
                    text: ''
                },
                tooltip: {
                    pointFormat: '<b>{point.percentage:.1f}%</b>',
                    style: {
                        color:'#fff',
                        fontSize:'12px',
                        opacity:0.8,
                        fontFamily:'Microsoft Yahei'
                    },
                    borderRadius:0,
                    borderColor:'#000',
                    backgroundColor:'#000'
                },
                credits: {
                      enabled: false
                },
                exporting: {
                  enabled: false
                },
                legend: {
                    enabled: true
                },
                plotOptions: {
                    pie: {
                        allowPointSelect: true,
                        cursor: 'pointer',
                        dataLabels: {
                            enabled: false,
                            format: '<b>{point.name}</b>: {point.percentage:.1f} %',
                            style: {
                                color: (Highcharts.theme && Highcharts.theme.contrastTextColor) || 'black'
                            }
                        },
                        showInLegend: true
                    }
                },
                //colors:['rgb(124, 181, 236)','rgb(244, 91, 91)'],
                series: [{
                    type: 'pie',
                    name: '',
                    data: [
                        ['男',   male],
                        ['女',   female]
                    ]
                }]
            });
        }`);


    load5:(male,female) =>
        $(`function () {
            $('#chart5').highcharts({
                chart: {
                    type: 'scatter',
                    zoomType: 'xy'
                },
                title: {
                    text: ''
                },
                subtitle: {
                    text: ''
                },
                credits: {
                    enabled: false
                },
                exporting: {
                    enabled: false
                },
                xAxis: {
                    title: {
                        enabled: true,
                        text: '出现时间',
                        style:{
                            fontFamily:'Microsoft Yahei'
                        }
                    },
                    type:"datetime",
                    dateTimeLabelFormats: {   
                            day: '%Y-%m-%d',  
                    },  
                    tickWidth: 0,
                    /*labels: {
                        enabled: false
                    },*/
                    tickPixelInterval: 150
                },
                yAxis: {
                    title: {
                        text: '年龄',
                        style:{
                            fontFamily:'Microsoft Yahei'
                        }
                    }
                },
                legend: {
                    layout: 'vertical',
                    align: 'right',
                    verticalAlign: 'middle',
                    //x: 100,
                    //y: 70,
                    //floating: true,
                    //backgroundColor: (Highcharts.theme && Highcharts.theme.legendBackgroundColor) || '#FFFFFF',
                    //borderWidth: 1
                },
                tooltip: {
                    formatter: function () {
                        return '性别：'+'<b>' + this.series.name + '</b><br/>' +
                        '出现时间：' + Highcharts.dateFormat('%Y-%m-%d %H:%M:%S', this.x) + '<br/>' +
                        '年龄：' + Highcharts.numberFormat(this.y, 0) + '岁';
                    },
                    style: {
                        color:'#fff',
                        fontSize:'12px',
                        opacity:0.8,
                        fontFamily:'Microsoft Yahei'
                    },
                    borderRadius:0,
                    borderColor:'#000',
                    backgroundColor:'#000'
                },
                plotOptions: {
                    scatter: {
                        marker: {
                            radius: 5,
                            states: {
                                hover: {
                                    enabled: true,
                                    lineColor: 'rgb(100,100,100)'
                                }
                            }
                        },
                        states: {
                            hover: {
                                marker: {
                                    enabled: false
                                }
                            }
                        },
                        tooltip: {
                            headerFormat: '<b>{series.name}</b><br>',
                            pointFormat: '{point.x}, {point.y} 岁'
                        }
                    }
                },
                series: [{
                    name: '女',
                    color: 'rgba(223, 83, 83, .5)',
                    data: female
                }, {
                    name: '男',
                    color: 'rgba(119, 152, 191, .5)',
                    data: male
                }]
            });
        }`);

    load6: () =>
        $(`function () {
            var categories = ['0-4', '5-9', '10-14', '15-19',
                              '20-24', '25-29', '30-34', '35-39', '40-44',
                              '45-49', '50-54', '55-59', '60-64', '65-69',
                              '70-74', '75-79', '80-84', '85-89', '90-94',
                              '95-99', '100 + '];
            $(document).ready(function () {
                $('#chart6').highcharts({
                    chart: {
                        type: 'bar'
                    },
                    title: {
                        text: ''
                    },
                    credits: {
                        enabled: false
                    },
                    exporting: {
                        enabled: false
                    },
                    xAxis: [{
                        categories: categories,
                        reversed: false,
                        labels: {
                            step: 1
                        }
                    }, { // mirror axis on right side
                        opposite: true,
                        reversed: false,
                        categories: categories,
                        linkedTo: 0,
                        labels: {
                            step: 1
                        }
                    }],
                    yAxis: {
                        title: {
                            text: null,
                            style:{
                                fontFamily:'Microsoft Yahei'
                            }
                        },
                        labels: {
                            formatter: function () {
                                return (Math.abs(this.value) / 1000000) + 'M';
                            }
                        },
                        min: -4000000,
                        max: 4000000
                    },
                    plotOptions: {
                        series: {
                            stacking: 'normal'
                        }
                    },
                    tooltip: {
                        formatter: function () {
                            return '<b>' + this.series.name + ', age ' + this.point.category + '</b><br/>' +
                                'Population: ' + Highcharts.numberFormat(Math.abs(this.point.y), 0);
                        },
                        style: {
                            color:'#fff',
                            fontSize:'12px',
                            opacity:0.8,
                            fontFamily:'Microsoft Yahei'
                        },
                        borderRadius:0,
                        borderColor:'#000',
                        backgroundColor:'#000'
                    },
                    series: [{
                        name: '男',
                        data: [-1746181, -1884428, -2089758, -2222362, -2537431, -2507081, -2443179,
                               -2664537, -3556505, -3680231, -3143062, -2721122, -2229181, -2227768,
                               -2176300, -1329968, -836804, -354784, -90569, -28367, -3878]
                    }, {
                        name: '女',
                        data: [1656154, 1787564, 1981671, 2108575, 2403438, 2366003, 2301402, 2519874,
                               3360596, 3493473, 3050775, 2759560, 2304444, 2426504, 2568938, 1785638,
                               1447162, 1005011, 330870, 130632, 21208]
                    }]
                });
            });
        }`);
    
    load7: (age)=>
        $(`function () {
            $('#chart7').highcharts({
                chart: {
                    type: 'pie',
                    options3d: {
                        enabled: true,
                        alpha: 45,
                        beta: 0
                    }
                },
                title: {
                    text: ''
                },
                legend: {
                    enabled:true,
                    layout: 'vertical',
                    align: 'right',
                    verticalAlign: 'middle',
                    verticalAlign: 'top',
                    labelFormatter: function () {
                        return this.name + '岁';
                    }
                },
                tooltip: {
                    pointFormat: '<b>{point.percentage:.1f}%</b>',
                    style: {
                        color:'#fff',
                        fontSize:'12px',
                        opacity:0.8,
                        fontFamily:'Microsoft Yahei'
                    },
                    borderRadius:0,
                    borderColor:'#000',
                    backgroundColor:'#000'
                },
                credits: {
                    enabled: false
                },
                exporting: {
                    enabled: false
                },
                plotOptions: {
                    pie: {
                        allowPointSelect: true,
                        cursor: 'pointer',
                        depth: 35,
                        dataLabels: {
                            enabled: false,
                            format: '{point.name}'
                        },
                        showInLegend: true
                    }
                },
                series: [{
                    type: 'pie',
                    name: '',
                    data: age
                }]
            });
        }`);

class ManagerPage extends DetailTablePage
    constructor: (@sd) ->
        super "managerpage-", "html/managerpage.html"

        $(@sd.manager).on "updated", (e, source) =>
            #@vm.user_data = @get_user_data()
            #@vm.journal = @subitems()

        @location_str = ""

    define_vm: (vm) =>
        vm.lang = lang.manager
        vm.user_data = @get_user_data()
        vm.journal = @subitems()
        vm.fattr_journal_status = fattr.journal_status
        vm.record_detail = @record_detail

        vm.users_num = ""
        vm.num_log = ""
        vm.num_compare = ""
        vm.num_recharge = ""
        vm.add_user = @add_user
        vm.delete_user = @delete_user

    rendered: () =>
        super()
        new WOW().init();
        $('.anchorBL').remove()
        $('.datepicker').remove()

        $scroller = $("#journals-scroller-1")
        $scroller.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true

        $scroller1 = $("#users-scroller-1")
        $scroller1.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller1.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true

        #@vm.user_data = @get_user_data()
        #@vm.journal = @subitems()
        @maper()
        #@maper_search(this)
        #@chart_level(this)
        @chart_active(this)
        @chart_pie(this)
        #@init_chart()
        @count_num()
        #@data_refresh()
        @datatable_init(this)
        @nprocess()

    nprocess:() =>
        NProgress.start()
        setTimeout (=> NProgress.done();$('.fade').removeClass('out')),1000
    
    datatable_init:(page) =>
        $(`function() {
            var table_users = $("#users-table").DataTable(dtable_opt({
                bProcessing: true,
                bServerSide: true,
                destroy:true,
                sAjaxSource: "http://" + page.sd.host + "/api/searchUsers",
                aoColumnDefs: [{
                    "aTargets": [5],
                    "mData": null,
                    "bSortable": false,
                    "bSearchable": false,
                    "mRender": function(data, type, full) {
                        return "<a class='btn mini green' id='view_detail'>查看</a><a class='btn mini red' id='delete_user'>删除</a>";
                    }
                },{
                    "aTargets": [0],
                    "mData": "5",
                    "bSortable": false,
                    "bSearchable": false,
                    "className": "dt-body-center",
                    "mRender": function(data, type, full) {
                        return '<input type="checkbox"  class="editor-active" />';
                    }
                }],
                rowCallback: function ( row, data ) {
                    // Set the checked state of the checkbox in the table
                    $('input.editor-active', row).prop( 'checked', data.active == 1 );
                },
                select: {
                    style: 'os',
                    selector: 'td:not(:last-child)' // no row selection on last column
                },
                fnServerData: function(sSource, aoData, fnCallback) {
                  return $.ajax({
                    "type": 'post',
                    "url": sSource,
                    "dataType": "json",
                    "data": aoData,
                    "success": function(resp) {
                      try{
                        return fnCallback(resp);
                      }catch(e){
                        return
                      }
                    },
                    "error": function(e) {
                      return console.log('error');
                    }
                  });
                }
            }));

            var table = $("#log-table1").DataTable(dtable_opt({
                /*retrieve: true,
                bSort: false,
                scrollX: true,*/
                bProcessing: true,
                bServerSide: true,
                destroy:true,
                sAjaxSource: "http://" + page.sd.host + "/api/searchRecord",
                aoColumnDefs: [
                  {
                    "aTargets": [3],
                    "mData": null,
                    "bSortable": false,
                    "bSearchable": false,
                    "mRender": function(data, type, full) {
                        return "<a class='btn mini green' id='view_detail'>查看</a>";
                    }
                  }, {
                    "aTargets": [1],
                    "mData": null,
                    "bSortable": false,
                    "bSearchable": false,
                    "mRender": function(data, type, full) {
                      if (full[1] === "info") {
                        return "<span class='label label-success'><i class='fa fa-volume-up'></i>提醒</span>";
                      } else if (full[1] === "warning") {
                        return "<span class='label label-warning'><i class='fa fa-warning-sign'></i>警告</span>";
                      } else {
                        return "<span class='label label-important'><i class='fa fa-remove'></i>错误</span>";
                      }
                    }
                  }
                ],
                fnServerData: function(sSource, aoData, fnCallback) {
                  var min = parseInt( $('#min').val());
                  var max = parseInt( $('#max').val());
                  var logtype = $('#logtype').val();
                  var start_Time = (Date.parse(new Date($('#start_time').val())))/1000;
                  var end_Time = (Date.parse(new Date($('#end_time').val())))/1000;

                  aoData.push({"name":"min","value":min});
                  aoData.push({"name":"max","value":max});
                  aoData.push({"name":"start_time","value":start_Time});
                  aoData.push({"name":"end_time","value":end_Time});
                  aoData.push({"name":"logtype","value":logtype});
                  return $.ajax({
                    "type": 'post',
                    "url": sSource,
                    "dataType": "json",
                    "data": aoData,
                    "success": function(resp) {
                      try{
                        return fnCallback(resp);
                      }catch(e){
                        return
                      }
                    },
                    "error": function(e) {
                      return console.log('error');
                    }
                  });
                }
            }));
            $(".dataTables_filter input").addClass("m-wrap small")
            $(".dataTables_length select").addClass("m-wrap small")
            /* 行详情 
            function format ( d ) {
                return 'Full name:';
            };

            var detailRows = [];
            $('#users-table tbody').on( 'click', 'tr td.details-control', function () {
                var tr = $(this).closest('tr');
                var row = table_users.row( tr );
                var idx = $.inArray( tr.attr('id'), detailRows );
         
                if ( row.child.isShown() ) {
                    tr.removeClass( 'details' );
                    row.child.hide();
                    detailRows.splice( idx, 1 );
                }
                else {
                    tr.addClass( 'details' );
                    row.child( format( row.data() ) ).show();
                    if ( idx === -1 ) {
                        detailRows.push( tr.attr('id') );
                    }
                }
            } );
         
            table_users.on( 'draw', function () {
                $.each( detailRows, function ( i, id ) {
                    $('#'+id+' td.details-control').trigger( 'click' );
                });
            });
            */

            // 复选框
            /*
            var check_all = []
            function removeByValue(arr, val) {
                for(var i=0; i<arr.length; i++) {
                  if(arr[i] == val) {
                    arr.splice(i, 1);
                    break;
                  }
                }
            }

            $('#users-table').on('change', 'tbody td input[type="checkbox"]', function(){
                var checka = table_users.row( $(this).closest('tr')).data();
                var id = checka['5']; 
                if(!this.checked){
                    removeByValue(check_all, id);
                }else{
                    check_all.push(id);
                }     
            });

            $("#delete_user").click(function () {
                console.log(check_all);
            });
            */

            $('#users-table tbody ').on( 'click', 'tr', function () {
                if ( $(this).hasClass('selected') ) {
                    $(this).removeClass('selected');
                }
                else {
                    table.$('tr.selected').removeClass('selected');
                    $(this).addClass('selected');
                }
            } );
            
            $('#users-table').on( 'change', 'input.editor-active', function () {
                var checka = table_users.row( $(this).closest('tr')).data();
                var id = checka['5']; 
                console.log(id);
            });

            /*$('#delete_user').click( function () {
                if (table.rows('.selected').data().length==0){
                    alert( table.rows('.selected').data().length +' row(s) selected, you should select the row you want to delete!' );
         
                }
                alert( table.rows('.selected').data().length +' row(s) selected, are you sure you want to delete this row?' );
         
                table.rows('.selected').remove().draw(false);
            } );*/

            $("#checkall").click(function () {
                var check = $(this).prop("checked");
                $(".checkchild").prop("checked", check);
            });

            //搜索框
            $('#min, #max, #start_time,#end_time ,#logtype').keyup( function() {
                table.draw();
            } );

            $('#log-table1 tbody').on( 'click', 'a', function () {
                var data = table.row( $(this).parents('tr') ).data();
                page.record_detail(data[ 3 ]);
            });
                     
            $('#users-table tbody').on( 'click', '#view_detail',function () {
                var data = table_users.row( $(this).parents('tr') ).data();
                page.view_detail(data[ 2 ]);
            });

            $('#users-table tbody').on( 'click', '#delete_user',function () {
                var data = table_users.row( $(this).parents('tr') ).data();
                page.delete_user(data[ 2 ]);
            });

            //时间选择器
            var nowTemp = new Date();
            var now = new Date(nowTemp.getFullYear(), nowTemp.getMonth(), nowTemp.getDate(), 0, 0, 0, 0);
            var checkin = $('#start_time').fdatepicker({
                /*
                onRender: function (date) {
                    return date.valueOf() < now.valueOf() ? 'disabled' : '';
                }
                */
            }).on('changeDate', function (ev) {
                if (ev.date.valueOf() > checkout.date.valueOf()) {
                    var newDate = new Date(ev.date);
                    newDate.setDate(newDate.getDate() + 1);
                    checkout.update(newDate);
                }
                checkin.hide();
                $('#end_time')[0].focus();
            }).data('datepicker')
            var checkout = $('#end_time').fdatepicker({
                onRender: function (date) {
                    return date.valueOf() <= checkin.date.valueOf() ? 'disabled' : '';
                }
            }).on('changeDate', function (ev) {
                table.draw();
                checkout.hide();
            }).data('datepicker');

        }`)

    view_detail:(account) =>
        (new RegisterDetailModal(@sd, this,account)).attach()

    delete_user:(uid) =>
        (new ConfirmModal @vm.lang.confirm_delete, =>
            @frozen()
            chain = new Chain
            chain.chain =>
                (new MachineRest @sd.host).delete_user uid
            chain.chain @sd.update("all")
            show_chain_progress(chain).done =>
                (new MessageModal (@vm.lang.delete_success)).attach()
                @attach()
        ).attach()

    add_user:() =>
       (new RegisterAddModal(@sd, this)).attach()

    data_refresh: ->
        chain = new Chain
        chain.chain @sd.update("manager")
        show_chain_progress(chain).done ->
            console.log "Refresh Managerpage"
        return

    get_user_data: () =>
        sub = []
        try
            @sd.manager.items.users
        catch e
            sub
            
    subitems:() =>
        sub = []
        try
            @sd.manager.items.records.reverse()
        catch e
            sub

    count_num: () =>
        totals = @get_user_data()
        num_com = 0
        num_rec = 0
        for i in totals
            num_com = num_com + parseInt(i.total)
            num_rec = num_rec + parseInt(i.recharge)

        @vm.users_num = totals.length
        @vm.num_log = @subitems().length
        @vm.num_compare = num_com
        @vm.num_recharge = num_rec

    init_chart:() =>
        try
            sub = []
            total = @get_user_data()
            for i in total
                locations = ""
                locations = i.location + i.hotelname
                sub.push locations
            @maps sub,this
        catch e
            console.log e

    record_detail:(uid) =>
        (new RegisterRecordModal(@sd, this,uid)).attach()

    chart_pie: (page) =>
        a = [18, 24, 27, 39, 26, 25, 20, 20]
        b = 109 
        c = 90
        @load3(a)
        @load4(b,c)

    load3: (num) =>
        $(`function () {
            var chart = AmCharts.makeChart("chart3", {
              "type": "radar",
              "theme": "light",
              "dataProvider": [],
              "valueAxes": [{
                "gridType": "circles",
                "minimum": 0
              }],
              "startDuration": 1,
              "polarScatter": {
                "minimum": 0,
                "maximum": 359,
                "step": 1
              },
              "legend": {
                "position": "right"
              },
              "graphs": [{
                "title": "Trial #1",
                "balloonText": "[[category]]: [[value]] m/s",
                "bullet": "round",
                "lineAlpha": 0,
                "series": [[83,5.1],[44,5.8],[76,9],[2,1.4],[100,8.3],[96,1.7],[68,3.9],[0,3],[100,4.1],[16,5.5],[71,6.8],[100,7.9],[9,6.8],[85,8.3],[51,6.7],[95,3.8],[95,4.4],[1,0.2],[107,9.7],[50,4.2],[42,9.2],[35,8],[44,6],[64,0.7],[53,3.3],[92,4.1],[43,7.3],[15,7.5],[43,4.3],[90,9.9]]
              }, {
                "title": "Trial #2",
                "balloonText": "[[category]]: [[value]] m/s",
                "bullet": "round",
                "lineAlpha": 0,
                "series": [[178,1.3],[129,3.4],[99,2.4],[80,9.9],[118,9.4],[103,8.7],[91,4.2],[151,1.2],[168,5.2],[168,1.6],[152,1.2],[149,3.4],[182,8.8],[106,6.7],[111,9.2],[130,6.3],[147,2.9],[81,8.1],[138,7.7],[107,3.9],[124,0.7],[130,2.6],[86,9.2],[169,7.5],[122,9.9],[100,3.8],[172,4.1],[140,7.3],[161,2.3],[141,0.9]]
              }, {
                "title": "Trial #3",
                "balloonText": "[[category]]: [[value]] m/s",
                "bullet": "round",
                "lineAlpha": 0,
                "series": [[419,4.9],[417,5.5],[434,0.1],[344,2.5],[279,7.5],[307,8.4],[279,9],[220,8.4],[204,8],[446,0.9],[397,8.9],[351,1.7],[393,0.7],[254,1.8],[260,0.4],[300,3.5],[199,2.7],[182,5.8],[173,2],[201,9.7],[288,1.2],[333,7.4],[308,1.9],[330,8],[408,1.7],[274,0.8],[296,3.1],[279,4.3],[379,5.6],[175,6.8]]
              }],
              "export": {
                "enabled": false
              }
            });
        }`);

    load4:(male,female) =>
        $(`function () {
            $('#chart4').highcharts({
                chart: {
                    plotBackgroundColor: null,
                    plotBorderWidth: null,
                    plotShadow: false
                },
                title: {
                    text: ''
                },
                tooltip: {
                    pointFormat: '<b>{point.percentage:.1f}%</b>'
                },
                credits: {
                      enabled: false
                },
                exporting: {
                  enabled: false
                },
                plotOptions: {
                    pie: {
                        allowPointSelect: true,
                        cursor: 'pointer',
                        dataLabels: {
                            enabled: true,
                            format: '<b>{point.name}</b>: {point.percentage:.1f} %',
                            style: {
                                color: (Highcharts.theme && Highcharts.theme.contrastTextColor) || 'black'
                            }
                        }
                    }
                },
                series: [{
                    type: 'pie',
                    name: '',
                    data: [
                        ['男',   male],
                        ['女',   female]
                    ]
                }]
            });
        }`);

    chart_active: () =>
        $(`function() {
            var chartData = [ {
              "date": "2012-01-01",
              "distance": 227,
              "townName": "New York",
              "townName2": "New York",
              "townSize": 25,
              "latitude": 40
            }, {
              "date": "2012-01-02",
              "distance": 371,
              "townName": "Washington",
              "townSize": 14,
              "latitude": 38
            }, {
              "date": "2012-01-03",
              "distance": 433,
              "townName": "Wilmington",
              "townSize": 6,
              "latitude": 34
            }, {
              "date": "2012-01-04",
              "distance": 345,
              "townName": "Jacksonville",
              "townSize": 7,
              "latitude": 30
            }, {
              "date": "2012-01-05",
              "distance": 480,
              "townName": "Miami",
              "townName2": "Miami",
              "townSize": 10,
              "latitude": 25
            }, {
              "date": "2012-01-06",
              "distance": 386,
              "townName": "Tallahassee",
              "townSize": 7,
              "latitude": 30
            }, {
              "date": "2012-01-07",
              "distance": 348,
              "townName": "New Orleans",
              "townSize": 10,
              "latitude": 29
            }, {
              "date": "2012-01-08",
              "distance": 238,
              "townName": "Houston",
              "townName2": "Houston",
              "townSize": 16,
              "latitude": 29
            }, {
              "date": "2012-01-09",
              "distance": 218,
              "townName": "Dalas",
              "townSize": 17,
              "latitude": 32
            }, {
              "date": "2012-01-10",
              "distance": 349,
              "townName": "Oklahoma City",
              "townSize": 11,
              "latitude": 35
            }, {
              "date": "2012-01-11",
              "distance": 603,
              "townName": "Kansas City",
              "townSize": 10,
              "latitude": 39
            }, {
              "date": "2012-01-12",
              "distance": 534,
              "townName": "Denver",
              "townName2": "Denver",
              "townSize": 18,
              "latitude": 39
            }, {
              "date": "2012-01-13",
              "townName": "Salt Lake City",
              "townSize": 12,
              "distance": 425,
              "latitude": 40,
              "alpha": 0.4
            }, {
              "date": "2012-01-14",
              "latitude": 36,
              "distance": 425,
              "townName": "Las Vegas",
              "townName2": "Las Vegas",
              "bulletClass": "lastBullet"
            }];
            var chart = AmCharts.makeChart( "amchart1", {

              "type": "serial",
              "theme": "light",
              "fontFamily":"Microsoft YaHei",
              
              "dataDateFormat": "YYYY-MM-DD",
              "dataProvider": chartData,

              "addClassNames": true,
              "startDuration": 1,
              //"color": "#FFFFFF",
              "marginLeft": 0,

              "categoryField": "date",
              "categoryAxis": {
                "parseDates": true,
                "minPeriod": "DD",
                "autoGridCount": false,
                "gridCount": 50,
                "gridAlpha": 0.1,
                "gridColor": "#FFFFFF",
                "axisColor": "#555555",
                "dateFormats": [ {
                  "period": 'DD',
                  "format": 'DD'
                }, {
                  "period": 'WW',
                  "format": 'MMM DD'
                }, {
                  "period": 'MM',
                  "format": 'MMM'
                }, {
                  "period": 'YYYY',
                  "format": 'YYYY'
                } ]
              },

              "valueAxes": [ {
                "id": "a1",
                "title": "在线人数",
                "gridAlpha": 0,
                "axisAlpha": 0
              }, {
                "id": "a2",
                "position": "right",
                "gridAlpha": 0,
                "axisAlpha": 0,
                "labelsEnabled": false
              }],
              "graphs": [ {
                "id": "g1",
                "valueField": "distance",
                "title": "在线人数",
                "type": "column",
                "fillAlphas": 0.9,
                "valueAxis": "a1",
                "balloonText": "[[value]] 人",
                "legendValueText": "[[value]] 人",
                "legendPeriodValueText": "总共: [[value.sum]] 人",
                "lineColor": "rgba(8, 163, 204,0.8)",
                "alphaField": "alpha"
              }, {
                "id": "g2",
                "valueField": "latitude",
                "classNameField": "bulletClass",
                "title": "充值人数",
                "type": "line",
                "valueAxis": "a2",
                "lineColor": "rgb(137, 196, 244)",
                "lineThickness": 1,
                "legendValueText": "[[value]] 人",
                "descriptionField": "townName",
                "bullet": "round",
                "bulletSizeField": "townSize",
                "bulletBorderColor": "rgb(2, 97, 122)",
                "bulletBorderAlpha": 1,
                "bulletBorderThickness": 2,
                "bulletColor": "rgba(137, 196, 244,1)",
                "labelText": "[[townName2]]",
                "labelPosition": "right",
                "balloonText": "充值人数:[[value]] 人",
                "showBalloon": true,
                "animationPlayed": true
              }],

              "chartCursor": {
                "zoomable": false,
                "categoryBalloonDateFormat": "DD",
                "cursorAlpha": 0,
                "valueBalloonsEnabled": false
              },
              "legend": {
                "bulletType": "round",
                "equalWidths": false,
                "valueWidth": 120,
                "useGraphSettings": true,
                //"color": "#FFFFFF"
              }
            } );
        }`)

    chart_level: (page)=>
        $(`function() {
            var xhr;  
            if (window.XMLHttpRequest){  
                xhr=new XMLHttpRequest();  
            }else{  
                xhr=new ActiveXObject("Microsoft.XMLHTTP");  
            }
            var id = page.sd.register.items["account"];
            xhr.open('get','http://' + page.sd.host + '/api/downloadAvatar/' + id ,true);
            xhr.send(null);
            xhr.onreadystatechange = function(){  
                if(xhr.readyState==4 || xhr.readyState==200){
                    var chart = AmCharts.makeChart("chart_level",
                    {
                        "type": "serial",
                        "theme": "light",
                        "dataProvider": [{
                            "name": "John",
                            "points": 35654,
                            "color": "#7F8DA9",
                            "bullet": xhr.responseText
                        }, {
                            "name": "Damon",
                            "points": 65456,
                            "color": "#FEC514",
                            "bullet": "https://www.amcharts.com/lib/images/faces/C02.png"
                        }, {
                            "name": "Patrick",
                            "points": 45724,
                            "color": "#DB4C3C",
                            "bullet": "https://www.amcharts.com/lib/images/faces/D02.png"
                        }, {
                            "name": "Mark",
                            "points": 13654,
                            "color": "#DAF0FD",
                            "bullet": "https://www.amcharts.com/lib/images/faces/E01.png"
                        }],
                        "valueAxes": [{
                            "maximum": 80000,
                            "minimum": 0,
                            "axisAlpha": 0,
                            "dashLength": 4,
                            "position": "left"
                        }],
                        "startDuration": 1,
                        "graphs": [{
                            "balloonText": "<span style='font-size:13px;'>[[category]]: <b>[[value]]</b></span>",
                            "bulletOffset": 10,
                            "bulletSize": 52,
                            "colorField": "color",
                            "cornerRadiusTop": 8,
                            "customBulletField": "bullet",
                            "fillAlphas": 0.8,
                            "lineAlpha": 0,
                            "type": "column",
                            "valueField": "points"
                        }],
                        "marginTop": 0,
                        "marginRight": 0,
                        "marginLeft": 0,
                        "marginBottom": 0,
                        "autoMargins": false,
                        "categoryField": "name",
                        "categoryAxis": {
                            "axisAlpha": 0,
                            "gridAlpha": 0,
                            "inside": true,
                            "tickLength": 0
                        },
                        "export": {
                            "enabled": false
                         }
                    });
                }  
            }

            
        }`)


    maper:() =>
        try
            sub = []
            total = @get_user_data()
            for i in total
                locations = ""
                locations = i.location + i.hotelname
                sub.push locations
            @maps sub,this
        catch e
            console.log e


    maps: (locations,page) =>
        $(`function() {
            try{
                var map = new BMap.Map("map");    // 创建Map实例
                
                map.centerAndZoom(new BMap.Point(116.404, 39.915), 11);  // 初始化地图,设置中心点坐标和地图级别
                map.addControl(new BMap.MapTypeControl());   //添加地图类型控件
                map.setCurrentCity("深圳");          // 设置地图显示的城市 此项是必须设置的
                map.enableScrollWheelZoom(true);     //开启鼠标滚轮缩放
                
                // 用经纬度设置地图中心点
                map.clearOverlays();//清空原来的标注
                var keyword = page.sd.register.items["location"] + page.sd.register.items["hotelname"];

                //var all_location = [];
                var localSearch = new BMap.LocalSearch(map);
                localSearch.enableAutoViewport(); //允许自动调节窗体大小

                localSearch.setSearchCompleteCallback(function (searchResult) {
                    try{
                        
                        var poi = searchResult.getPoi(0);
                        
                        //var single_location = {};
                        //single_location["zoomLevel"] = 5;
                        //single_location["scale"] = 0.5;
                        //single_location["title"] = poi.address;
                        //single_location["latitude"] = poi.point.lat;
                        //single_location["longitude"] = poi.point.lng;
                        //all_location.push(single_location);
                        

                        var marker = new BMap.Marker(new BMap.Point(poi.point.lng, poi.point.lat));  // 创建标注，为要查询的地方对应的经纬度
                        map.addOverlay(marker);
                        map.centerAndZoom(poi.point, 10);

                        var content = poi.address + "<br/><br/>经度：" + poi.point.lng + "<br/>纬度：" + poi.point.lat;

                        var infoWindow = new BMap.InfoWindow("<p style='font-size:14px;'>" + content + "</p>");
                        marker.addEventListener("click", function () { this.openInfoWindow(infoWindow); });
                    }catch(e){
                        return
                        //console.log(e);
                        //return (new MessageModal(lang.register.address_error)).attach();
                    }
                });
                $('.anchorBL').remove();
                
                for (i = 0, len = locations.length; i < len; i++) {
                    if (locations[i] !== ""){
                        localSearch.search(locations[i]);
                    }
                }
                //if (all_location.length !== 0){
                    //page.amap(all_location);
                //}
                //setTimeout(function(){
                    //map.setZoom(20);   
                //}, 2000);  //2秒后放大到14级
            }catch(e){
                return (new MessageModal(lang.register.part_map_error)).attach();
            }
        }`)


    maper_search:(page) =>
        $(`function() {
            var xhr;  
            if (window.XMLHttpRequest){  
                xhr=new XMLHttpRequest();  
            }else{  
                xhr=new ActiveXObject("Microsoft.XMLHTTP");  
            }
            try{
                var sub = [];
                total = page.get_user_data();
                for (_i = 0, _len = total.length; _i < _len; _i++) {
                    i = total[_i];
                    if (i.hotelname != "" && i.location != ""){
                        xhr.open('get','http://api.map.baidu.com/geocoder/v2/?address=' + i.location + i.hotelname + '&output=json&ak=SGlfxoEEgdtmV60T195lr7BYx6bFLvkI&callback=showLocation' ,true);
                        xhr.send(null);
                        xhr.onreadystatechange = function(){  
                            if(xhr.readyState==4 || xhr.readyState==200){
                                //var _data = JSON.parse(xhr.responseText);
                                //page._count =  xhr.responseText;
                                //sub.push(locations);
                                console.log(xhr.responseText);  
                            }  
                        }
                    }
                }
            }catch(e){
                return (new MessageModal(lang.manager.map_error)).attach();
            }
        }`)

    ammaps: (locations,page) =>
        $(`function() {
            try{
                var targetSVG = "M9,0C4.029,0,0,4.029,0,9s4.029,9,9,9s9-4.029,9-9S13.971,0,9,0z M9,15.93 c-3.83,0-6.93-3.1-6.93-6.93S5.17,2.07,9,2.07s6.93,3.1,6.93,6.93S12.83,15.93,9,15.93 M12.5,9c0,1.933-1.567,3.5-3.5,3.5S5.5,10.933,5.5,9S7.067,5.5,9,5.5 S12.5,7.067,12.5,9z";
                var planeSVG = "M19.671,8.11l-2.777,2.777l-3.837-0.861c0.362-0.505,0.916-1.683,0.464-2.135c-0.518-0.517-1.979,0.278-2.305,0.604l-0.913,0.913L7.614,8.804l-2.021,2.021l2.232,1.061l-0.082,0.082l1.701,1.701l0.688-0.687l3.164,1.504L9.571,18.21H6.413l-1.137,1.138l3.6,0.948l1.83,1.83l0.947,3.598l1.137-1.137V21.43l3.725-3.725l1.504,3.164l-0.687,0.687l1.702,1.701l0.081-0.081l1.062,2.231l2.02-2.02l-0.604-2.689l0.912-0.912c0.326-0.326,1.121-1.789,0.604-2.306c-0.452-0.452-1.63,0.101-2.135,0.464l-0.861-3.838l2.777-2.777c0.947-0.947,3.599-4.862,2.62-5.839C24.533,4.512,20.618,7.163,19.671,8.11z";
                var map = AmCharts.makeChart( "map", {
                  "type": "map",
                  "theme": "light",
                  "dataProvider": {
                    "map": "worldLow",
                    "zoomLevel": 3.5,
                    "zoomLongitude": -20.1341,
                    "zoomLatitude": 49.1712,

                    "lines": [ {
                      "latitudes": [ 51.5002, 50.4422 ],
                      "longitudes": [ -0.1262, 30.5367 ]
                    }, {
                      "latitudes": [ 51.5002, 46.9480 ],
                      "longitudes": [ -0.1262, 7.4481 ]
                    }, {
                      "latitudes": [ 51.5002, 59.3328 ],
                      "longitudes": [ -0.1262, 18.0645 ]
                    }, {
                      "latitudes": [ 51.5002, 40.4167 ],
                      "longitudes": [ -0.1262, -3.7033 ]
                    }, {
                      "latitudes": [ 51.5002, 46.0514 ],
                      "longitudes": [ -0.1262, 14.5060 ]
                    }, {
                      "latitudes": [ 51.5002, 48.2116 ],
                      "longitudes": [ -0.1262, 17.1547 ]
                    }, {
                      "latitudes": [ 51.5002, 44.8048 ],
                      "longitudes": [ -0.1262, 20.4781 ]
                    }, {
                      "latitudes": [ 51.5002, 55.7558 ],
                      "longitudes": [ -0.1262, 37.6176 ]
                    }, {
                      "latitudes": [ 51.5002, 38.7072 ],
                      "longitudes": [ -0.1262, -9.1355 ]
                    }, {
                      "latitudes": [ 51.5002, 54.6896 ],
                      "longitudes": [ -0.1262, 25.2799 ]
                    }, {
                      "latitudes": [ 51.5002, 64.1353 ],
                      "longitudes": [ -0.1262, -21.8952 ]
                    }, {
                      "latitudes": [ 51.5002, 40.4300 ],
                      "longitudes": [ -0.1262, -74.0000 ]
                    } ],
                    "images": [ {
                      "id": "london",
                      "svgPath": targetSVG,
                      "title": "London",
                      "latitude": 51.5002,
                      "longitude": -0.1262,
                      "scale": 1
                    }, {
                      "svgPath": targetSVG,
                      "title": "Brussels",
                      "latitude": 50.8371,
                      "longitude": 4.3676,
                      "scale": 0.5
                    }, {
                      "svgPath": targetSVG,
                      "title": "Prague",
                      "latitude": 50.0878,
                      "longitude": 14.4205,
                      "scale": 0.5
                    }, {
                      "svgPath": targetSVG,
                      "title": "Athens",
                      "latitude": 37.9792,
                      "longitude": 23.7166,
                      "scale": 0.5
                    }, {
                      "svgPath": targetSVG,
                      "title": "Reykjavik",
                      "latitude": 64.1353,
                      "longitude": -21.8952,
                      "scale": 0.5
                    }, {
                      "svgPath": targetSVG,
                      "title": "Dublin",
                      "latitude": 53.3441,
                      "longitude": -6.2675,
                      "scale": 0.5
                    }, {
                      "svgPath": targetSVG,
                      "title": "Oslo",
                      "latitude": 59.9138,
                      "longitude": 10.7387,
                      "scale": 0.5
                    }, {
                      "svgPath": targetSVG,
                      "title": "Lisbon",
                      "latitude": 38.7072,
                      "longitude": -9.1355,
                      "scale": 0.5
                    }, {
                      "svgPath": targetSVG,
                      "title": "Moscow",
                      "latitude": 55.7558,
                      "longitude": 37.6176,
                      "scale": 0.5
                    }, {
                      "svgPath": targetSVG,
                      "title": "Belgrade",
                      "latitude": 44.8048,
                      "longitude": 20.4781,
                      "scale": 0.5
                    }, {
                      "svgPath": targetSVG,
                      "title": "Bratislava",
                      "latitude": 48.2116,
                      "longitude": 17.1547,
                      "scale": 0.5
                    }, {
                      "svgPath": targetSVG,
                      "title": "Ljubljana",
                      "latitude": 46.0514,
                      "longitude": 14.5060,
                      "scale": 0.5
                    }, {
                      "svgPath": targetSVG,
                      "title": "Madrid",
                      "latitude": 40.4167,
                      "longitude": -3.7033,
                      "scale": 0.5
                    }, {
                      "svgPath": targetSVG,
                      "title": "Stockholm",
                      "latitude": 59.3328,
                      "longitude": 18.0645,
                      "scale": 0.5
                    }, {
                      "svgPath": targetSVG,
                      "title": "Bern",
                      "latitude": 46.9480,
                      "longitude": 7.4481,
                      "scale": 0.5
                    }, {
                      "svgPath": targetSVG,
                      "title": "Kiev",
                      "latitude": 50.4422,
                      "longitude": 30.5367,
                      "scale": 0.5
                    }, {
                      "svgPath": targetSVG,
                      "title": "Paris",
                      "latitude": 48.8567,
                      "longitude": 2.3510,
                      "scale": 0.5
                    }, {
                      "svgPath": targetSVG,
                      "title": "New York",
                      "latitude": 40.43,
                      "longitude": -74,
                      "scale": 0.5
                    } ]
                  },

                  "areasSettings": {
                    "unlistedAreasColor": "#FFCC00",
                    "unlistedAreasAlpha": 0.9
                  },

                  "imagesSettings": {
                    "color": "#CC0000",
                    "rollOverColor": "#CC0000",
                    "selectedColor": "#000000"
                  },

                  "linesSettings": {
                    "arc": -0.7, // this makes lines curved. Use value from -1 to 1
                    "arrow": "middle",
                    "color": "#CC0000",
                    "alpha": 0.4,
                    "arrowAlpha": 1,
                    "arrowSize": 4
                  },
                  "zoomControl": {
                    "gridHeight": 100,
                    "draggerAlpha": 1,
                    "gridAlpha": 0.2
                  },

                  "backgroundZoomsToTop": true,
                  "linesAboveImages": true,
                  
                  "export": {
                    "enabled": true
                  }
                });
            }catch(e){
                return (new MessageModal(lang.register.map_error)).attach();
            }
        }`)
    
    amap: (all_location) =>
        $(`function() {
            var map = AmCharts.makeChart( "map", {
              "type": "map",
              "theme": "light",
              "projection": "miller",

              "imagesSettings": {
                "rollOverColor": "#089282",
                "rollOverScale": 3,
                "selectedScale": 3,
                "selectedColor": "#089282",
                "color": "#13564e"
              },

              "areasSettings": {
                "unlistedAreasColor": "#15A892"
              },

              "dataProvider": {
                "map": "worldLow",
                "images": all_location
              }
            });

            // add events to recalculate map position when the map is moved or zoomed
            map.addListener( "positionChanged", updateCustomMarkers );

            // this function will take current images on the map and create HTML elements for them
            function updateCustomMarkers( event ) {
              // get map object
              var map = event.chart;

              // go through all of the images
              for ( var x in map.dataProvider.images ) {
                // get MapImage object
                var image = map.dataProvider.images[ x ];

                // check if it has corresponding HTML element
                if ( 'undefined' == typeof image.externalElement )
                  image.externalElement = createCustomMarker( image );

                // reposition the element accoridng to coordinates
                var xy = map.coordinatesToStageXY( image.longitude, image.latitude );
                image.externalElement.style.top = xy.y + 'px';
                image.externalElement.style.left = xy.x + 'px';
              }
            }

            // this function creates and returns a new marker element
            function createCustomMarker( image ) {
              // create holder
              var holder = document.createElement( 'div' );
              holder.className = 'map-marker';
              holder.title = image.title;
              holder.style.position = 'absolute';

              // maybe add a link to it?
              if ( undefined != image.url ) {
                holder.onclick = function() {
                  window.location.href = image.url;
                };
                holder.className += ' map-clickable';
              }

              // create dot
              var dot = document.createElement( 'div' );
              dot.className = 'dot';
              holder.appendChild( dot );

              // create pulse
              var pulse = document.createElement( 'div' );
              pulse.className = 'pulse';
              holder.appendChild( pulse );

              // append the marker to the map container
              image.chart.chartDiv.appendChild( holder );

              return holder;
            }
        }`)

###########################  old  #########################
this.DetailTablePage = DetailTablePage
this.DiskPage = DiskPage
this.InitrPage = InitrPage
this.LoginPage = LoginPage
this.MaintainPage = MaintainPage
this.OverviewPage = OverviewPage
this.QuickModePage = QuickModePage
this.RaidPage = RaidPage
this.SettingPage = SettingPage
this.VolumePage = VolumePage
this.Page = Page

############################  cloud  #######################

this.CentralLoginPage = CentralLoginPage
this.CentralStoremonitorPage = CentralStoremonitorPage
this.CentralServermonitorPage = CentralServermonitorPage
this.CentralStoreDetailPage = CentralStoreDetailPage
this.CentralServerDetailPage = CentralServerDetailPage
this.CentralServerViewPage = CentralServerViewPage
this.CentralStoreViewPage = CentralStoreViewPage
this.CentralServerlistPage = CentralServerlistPage
this.CentralStorelistPage = CentralStorelistPage
this.CentralClientlistPage = CentralClientlistPage
this.CentralWarningPage = CentralWarningPage
this.CentralMonitorPage = CentralMonitorPage

####################pay##############################
this.PreCountPage = PreCountPage
this.RegisterPage = RegisterPage
this.FacePage = FacePage
this.CountPage = CountPage
this.ManagerPage = ManagerPage

this.FaceQuickPage = FaceQuickPage
this.FaceQuickProPage = FaceQuickProPage