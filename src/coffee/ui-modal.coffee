class Modal extends AvalonTemplUI
    constructor: (@prefix, @src, @attr={}) ->
        $.extend(@attr, class: "modal fade")
        super @prefix, @src, "body", false, @attr

    attach: () =>
        $("body").modalmanager "loading"
        super()

    rendered: () =>
        super()
        $div = $("##{@id}")
        $div.on "hide", (e) =>
            if e.currentTarget == e.target
                setTimeout (=> @detach()), 1000
        $div.modal({backdrop:"static"})
        $(".tooltips").tooltip()
        #Nprogress
        #NProgress.start()
        #setTimeout (=> NProgress.done();$('.fade').removeClass('out')),10

    hide: () =>
        $("##{@id}").modal("hide")

class ServerUI extends Modal
    constructor: (@serverUI=server_type) ->
        super "confirm-", 'html/serverui.html',\
        style: "max-width:400px;left:60%;text-align:center"
        
    define_vm: (vm) =>
        vm.lang = lang.server
        vm.central = @central
        vm.store = @store
   
    rendered: () =>
        super()
        @backstretch = $(".login").backstretch([
            "images/login-bg/4a.jpg",
            ], fade: 1000, duration: 5000).data "backstretch"

    store: () =>
        @serverUI.type = 'store'
        window.adminview = new AdminView(@serverUI)
        avalon.scan()
        App.init()
        
    central: () =>
        @serverUI.type = 'central'
        @serverUI.store = false
        window.adminview = new CentralView(@serverUI)
        avalon.scan()
        App.init()    

class MessageModal extends Modal
    constructor: (@message, @callback=null) ->
        super "message-", "html/message_modal.html"

    define_vm: (vm) =>
        vm.message = @message
        vm.lang = lang.message_modal
        vm.callback = => @callback?()

class MessageModal_reboot extends Modal
    constructor: (@message,@bottom,@dview,@sd,@settings) ->
        super "message-", "html/message_modal_reboot.html"
        
    define_vm: (vm) =>
        vm.message = @message
        vm.lang = lang.message_modal
        vm.recovered = @bottom
        vm.reboot = @reboot

    reboot: () =>
        chain = new Chain()
        chain.chain => (new CommandRest(@dview.sd.host)).reboot()
        @hide()
        show_chain_progress(chain, true).fail =>
            @settings.removeLoginedMachine @dview.host
            @sd.close_socket()
            arr_remove sds, @sd
            setTimeout(@dview.switch_to_login_page, 2000)

class CentralSearchModal extends Modal
    constructor: (@sd, @page, @machines, @type) ->
        console.log @page
        super "central-search-modal-", "html/central_search_modal.html"
        
    define_vm: (vm) =>
        vm.machines = @subitems()
        vm.lang = lang.central_search_modal
        vm.all_checked = false
        vm.submit = @submit

        vm.$watch "all_checked", =>
            for v in vm.machines
                v.checked = vm.all_checked

    rendered: () =>
        super()
        $("form.machines").validate(
            valid_opt(
                rules:
                    'machine-checkbox':
                        required: true
                        minlength: 1
                messages:
                    'machine-checkbox': "请选择至少一个虚拟磁盘"))
        
    submit: () =>
        if $("form.machines").validate().form()
            selecteds = []
            for i in @vm.machines when i.checked
                selecteds.push i
            @monitoring selecteds
            
    monitoring: (devices) =>
        chain = new Chain
        for device in devices
            uuid = device.uuid + device.ifaces[0].split('.').join('')
            chain.chain @_eachMonitor(uuid, device.ifaces[0])
        chain.chain @sd.update('all')
        @hide()
        show_chain_progress(chain).done (data)=>
            (new MessageModal lang.central_search_modal.monitor_success).attach()
            #@tips(devices)
            @page.attach()
        .fail =>
            (new MessageModal lang.central_search_modal.monitor_error).attach()

    _eachMonitor: (uuid, ip, slotnr=24) =>
        return ()=> (new MachineRest(@sd.host) ).monitor uuid, ip, slotnr, @type
    
    tips:(devices) =>
        try
            info = []
            datas = {}
            for i in devices
                info.push i.ifaces[0]
                datas[i.ifaces[0]] = 0
            ((datas[j.ip] = datas[j.ip] + 1 )for j in @sd.stores.items.journals when j.ip in info)
            for k in info
                if datas[k] > 0
                    if @type is "storage"
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
        
    subitems: () =>
        items = subitems @machines, uuid:"", ifaces:"", Slotnr:24,\
             checked:false
        return items
             
class CentralRecordDeleteModal extends Modal
    constructor: (@sd, @page, @message) ->
        super "central-delete-modal-","html/central_delete_modal.html"

    define_vm: (vm) =>
        vm.lang = lang.central_delete_modal
        vm.submit = @submit
        vm.message = @message

    rendered: () =>
        super()

    submit: () =>
        for i in @message
            @page.frozen()
            chain = new Chain
            chain.chain => (new MachineRest(@sd.host)).delete_record i.uuid
            chain.chain @sd.update('clouds')
            @hide()
            show_chain_progress(chain).done =>
        @page.attach()
        (new MessageModal(@vm.lang.delete_success)).attach()
        
class CentralEmailDeleteModal extends Modal
    constructor: (@sd, @page, @message) ->
        super "central-delete-modal-","html/central_delete_modal.html"

    define_vm: (vm) =>
        vm.lang = lang.central_delete_modal
        vm.submit = @submit
        vm.message = @message

    rendered: () =>
        super()

    submit: () =>
        for i in @message
            @page.frozen()
            chain = new Chain
            chain.chain => (new MachineRest(@sd.host)).delete_email i.address
            chain.chain @sd.update('all')
            @hide()
            show_chain_progress(chain).done =>
                @page.attach()
        (new MessageModal(@vm.lang.delete_success)).attach()
        
class CentralServerCpuModal extends Modal
    constructor: (@sd, @page) ->
        super "central-server-cpu-modal-", "html/central_server_cpu_modal.html"
        $(@sd.stats).on "updated", (e, source) =>
            if @has_rendered
                @vm.cpu = @subitems()
                
    define_vm: (vm) =>
        vm.lang = lang.central_server_cpu_modal
        vm.submit = @submit
        vm.cpu = @subitems()
        vm.rendered = @rendered
    rendered: () =>
        super()
        @data_table = $("#cpu-table").dataTable dtable_opt(retrieve: true)
        $(".dataTables_filter input").addClass "m-wrap small"
        $(".dataTables_length select").addClass "m-wrap small"
        $scroller = $("#journals-scroller")
        $scroller.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
            
    subitems: () =>
        items = @sd.stats.items
        latest = items[items.length-1]
        tmp = []
        try
            for i in latest.master.process
                if i.protype isnt 'total' and i.cpu isnt 0
                    tmp.push i
            return tmp
        catch error
            return tmp
    submit: () =>
        @hide()
            
class CentralServerCacheModal extends Modal
    constructor: (@sd, @page) ->
        super "central-server-cache-modal-", "html/central_server_cache_modal.html"
        
    define_vm: (vm) =>
        vm.lang = lang.central_server_cache_modal
        vm.submit = @submit
        vm.cache = @subitems()
        vm.rendered = @rendered
    rendered: () =>
        super()
        @data_table = $("#cache-table").dataTable dtable_opt(retrieve: true)
        $(".dataTables_filter input").addClass "m-wrap small"
        $(".dataTables_length select").addClass "m-wrap small"
        
        $scroller = $("#journals-scroller")
        $scroller.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
    subitems: () =>
        items = @sd.stats.items
        latest = items[items.length-1]
        tmp = []
        try
            for i in latest.master.process
                if i.protype isnt 'total'
                    tmp.push i
            return tmp
        catch error
            return tmp
    submit: () =>
        @hide()
            
class CentralServerMemModal extends Modal
    constructor: (@sd, @page) ->
        super "central-server-mem-modal-", "html/central_server_mem_modal.html"
        $(@sd.stats).on "updated", (e, source) =>
            if @has_rendered
                @vm.mem = @subitems()
    define_vm: (vm) =>
        vm.lang = lang.central_server_mem_modal
        vm.submit = @submit
        vm.mem = @subitems()
        vm.rendered = @rendered
    rendered: () =>
        super()
        @data_table = $("#mem-table").dataTable dtable_opt(retrieve: true)
        $(".dataTables_filter input").addClass "m-wrap small"
        $(".dataTables_length select").addClass "m-wrap small"
        
        $scroller = $("#journals-scroller")
        $scroller.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
    subitems: () =>
        items = @sd.stats.items
        latest = items[items.length-1]
        tmp = []
        try
            for i in latest.master.process
                if i.protype isnt 'total' and i.mem isnt 0
                    tmp.push i
            return tmp
        catch error
            return tmp
    submit: () =>
        @hide()
        
class CentralStoreDetailModal extends Modal
    constructor: (@sd, @page, @message) ->
        super "central-store-detail-modal-", "html/central_store_detail_modal.html"
        
    define_vm: (vm) =>
        vm.lang = lang.central_store_detail_modal
        vm.submit = @submit
        vm.disks = @subitems_disks()
        vm.raids = @subitems_raids()
        vm.volumes = @subitems_volumes()
        vm.filesystems = @subitems_filesystems()
        vm.initiators = @subitems_initiators()
        
        vm.rendered = @rendered
        
    rendered: () =>
        super()
        @data_table = $("#volume-table").dataTable dtable_opt(retrieve: true)
        $(".dataTables_filter input").addClass "m-wrap small"
        $(".dataTables_length select").addClass "m-wrap small"
        $scroller = $("#journals-scroller")
        $scroller.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
            
    subitems: () =>
        temp = []
        for i in @message
            temp.push i
        return temp
    subitems: () =>
        temp = []
        for i in @message
            temp.push i
        return temp
    subitems: () =>
        temp = []
        for i in @message
            temp.push i
        return temp
    subitems: () =>
        temp = []
        for i in @message
            temp.push i
        return temp
    subitems: () =>
        temp = []
        for i in @message
            temp.push i
        return temp
    subitems: () =>
        temp = []
        for i in @message
            temp.push i
        return temp
        
    submit: () =>
        @hide()
        
class CentralPieModal extends Modal
    constructor: (@sd, @page, @type, @total, @used) ->
        super "central-pie-modal-", "html/central_pie_modal.html"
        @refresh_pie()
        
    define_vm: (vm) =>
        vm.lang = lang.central_pie_modal
        vm.submit = @submit
        vm.rendered = @rendered
        vm.type = @type
        
    rendered: () =>
        super()
        @refresh_pie()
    subitems: () =>
        return
        
    refresh_pie: () =>
        try
            if @type is '已用容量'
                datas_used = @get_used()
                @plot_pie datas_used,@type
            else
                @type = '总容量'
                datas_total = @get_cap()
                @plot_pie datas_total,@type
        catch error
            console.log error
            
    get_used: () =>
        data_used = {}
        datas_used = []
        machine_used = []
        
        for i in @sd.stores.items.Raid
            if i.MachineId not in machine_used
                machine_used.push i.MachineId
                
        for i in @sd.stores.items.Raid
            data_used[i.MachineId] = 0
            
        for i in @sd.stores.items.Raid
            data_used[i.MachineId] = data_used[i.MachineId] + i.Used
            
        for i in machine_used
            datas_used.push {name:i,y:data_used[i]/@used*100}
            
        for i in datas_used
            for j in @sd.centers.items
                if i['name'] is j.Uuid
                    i['name'] = j.Ip 
        datas_used
        
    get_cap: () =>
        data_total = {}
        datas_total = []
        machine_total = []
        for i in @sd.stores.items.Disk
            if i.MachineId not in machine_total
                machine_total.push i.MachineId
                
        for i in @sd.stores.items.Disk
            data_total[i.MachineId] = 0
           
        for i in @sd.stores.items.Disk
            data_total[i.MachineId] = data_total[i.MachineId] + i.CapSector/2/1024/1024
            
        for i in machine_total
            datas_total.push {name:i,y:data_total[i]/@total*100}
            
        for i in datas_total
            for j in @sd.centers.items
                if i['name'] is j.Uuid
                    i['name'] = j.Ip 
        datas_total
        
    plot_pie: (datas, type) =>
        Highcharts.setOptions(
            lang:
                contextButtonTitle:"图表导出菜单"
                decimalPoint:"."
                downloadJPEG:"下载JPEG图片"
                downloadPDF:"下载PDF文件"
                downloadPNG:"下载PNG文件"
                downloadSVG:"下载SVG文件"
                printChart:"打印图表")
        
        $('#pie_charts').highcharts(
                chart: 
                    type: 'pie'
                    options3d:
                        enabled: true
                        alpha: 45
                        beta: 0
                    marginBottom:70
                title: 
                    text: type
                    align:'center'
                    verticalAlign: 'top'
                    style:
                        fontWeight:'bold'
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
                        depth: 35
                        slicedOffset: 15
                        showInLegend: true
                        dataLabels: 
                            enabled: true
                            format: '{point.percentage:.1f} %'
                            style: 
                                fontSize:'14px'
                        point:
                            events:
                                legendItemClick: () ->return false
                legend:
                    backgroundColor: '#FFFFFF'
                    layout: 'vertical'
                    floating: true
                    align: 'center'
                    verticalAlign: 'bottom'
                    itemMarginBottom: 5
                    x: 0
                    y: 20
                    labelFormatter: () ->
                        return @name
                series: [
                    type: 'pie'
                    name: ''
                    data: datas
                ])
                
    submit: () =>
        @hide()
        
class ConfirmModal_unlink extends Modal
    constructor: (@message, @confirm, @cancel,@warn) ->
        super "confirm-", "html/confirm_Initr.html"

    define_vm: (vm) =>
        vm.message = @message
        vm.lang = lang.confirm_modal
        vm.warn = lang.initr_unlink_modal
        vm.submit_confirm = => @confirm?()
        vm.cancel = => @cancel?()
        
class ConfirmModal_link extends Modal
    constructor: (@message, @confirm, @cancel,@warn) ->
        super "confirm-", "html/confirm_Initr.html"

    define_vm: (vm) =>
        vm.message = @message
        vm.lang = lang.confirm_modal
        vm.warn = lang.initr_link_modal
        vm.submit_confirm = => @confirm?()
        vm.cancel = => @cancel?()
            
class ConfirmModal extends Modal
    constructor: (@message, @confirm, @cancel) ->
        super "confirm-", "html/confirm_modal.html"

    define_vm: (vm) =>
        vm.message = @message
        vm.lang = lang.confirm_modal
        vm.submit_confirm = => @confirm?()
        vm.cancel = => @cancel?()


class ConfirmModal_more extends Modal
    constructor: (@title,@message,@sd,@dview,@settings) ->
        super "confirm-", "html/confirm_vaildate_modal.html"
        @settings = new SettingsManager
    define_vm: (vm) =>
        vm.title = @title
        vm.message = @message
        vm.lang = lang.confirm_vaildate_modal
        vm.confirm = true
        vm.confirm_passwd = ""
        vm.submit = @submit
        vm.bottom = true
        vm.sysinit = @sysinit
        vm.recover = @recover
        vm.keypress_passwd = @keypress_passwd
        
    rendered: () =>
        super()
        $.validator.addMethod("same", (val, element) =>
            if @vm.confirm_passwd != 'passwd'
                return false
            else
                return true
        , "密码输入错误")

        $("form.passwd").validate(
            valid_opt(
                rules:
                    confirm_passwd:
                        required: true
                        maxlength: 32
                        same: true
                messages:
                    confirm_passwd:
                        required: "请输入正确的确认密码"
                        maxlength: "密码长度不能超过32个字符"))

    submit: () =>
        if @title == @vm.lang.btn_sysinit
            @sysinit()
        else if @title == @vm.lang.btn_recover
            @recover()

    keypress_passwd: (e) =>
        @submit() if e.which is 13    

    sysinit: () =>
        if $("form.passwd").validate().form()
            chain = new Chain()
            chain.chain => (new CommandRest(@dview.sd.host)).sysinit()
            @hide()
            show_chain_progress(chain, true).fail (data)=>
                @settings.removeLoginedMachine @dview.host
                @sd.close_socket()
                arr_remove sds, @sd
                setTimeout(@dview.switch_to_login_page, 2000)
             
    recover: () =>
        if $("form.passwd").validate().form()
            chain = new Chain()
            chain.chain => (new CommandRest(@dview.sd.host)).recover()
            @hide()
            show_chain_progress(chain, true).done (data)=>
                (new MessageModal_reboot(lang.maintainpage.finish_recover,@vm.bottom,@dview,@sd,@settings)).attach()
            .fail (data)=>
                console.log "error"
                console.log data
                
class ConfirmModal_scan extends Modal
    constructor: (@sd, @page, @title, @message, @fs) ->
        super "confirm-", "html/confirm_reboot_modal.html"
        
    define_vm: (vm) =>
        vm.lang = lang.confirm_reboot_modal
        vm.title = @title
        vm.message = @message
        vm.submit = @reboot
        vm.res = @fs

    reboot: () =>
        chain = new Chain()
        chain.chain => (new CommandRest(@sd.host)).reboot()
        @hide()
        show_chain_progress(chain, true).fail =>
            @sd.close_socket()
            arr_remove sds, @sd      
            
class ResDeleteModal extends Modal
    constructor: (prefix, @page, @res, @lang) ->
        super prefix, 'html/res_delete_modal.html'

    define_vm: (vm) =>
        vm.lang = @lang
        vm.res = @res
        vm.submit = @submit

    rendered: () =>
        $(".chosen").chosen()
        super()

    submit: () =>
        chain = @_submit($(opt).prop "value" for opt in $(".modal-body :selected"))
        @hide()
        show_chain_progress(chain).done =>
            @page.attach()

class SyncDeleteModal extends ResDeleteModal
    constructor: (@sd, page, res) ->
        super "sync-delete-", page, res, lang.confirm_sync_modal
        
    _submit: (real_failed_volumes) =>
        @page.frozen()
        chain = new Chain
        chain.chain($.map(real_failed_volumes, (v) => (=> (new SyncConfigRest(@sd.host)).sync_disable v)))
            .chain @sd.update("volumes")
        return chain
            
class RaidDeleteModal extends ResDeleteModal
    constructor: (@sd, page, res) ->
        super "raid-delete-", page, res, lang.raid_delete_modal

    _submit: (deleted) =>
        @page.frozen()
        chain = new Chain
        chain.chain($.map(deleted, (r) => (=> (new RaidRest(@sd.host)).delete r)))
            .chain @sd.update("raids")
        return chain

class RaidCreateDSUUI extends AvalonTemplUI
    constructor: (@sd, parent_selector, @enabled=['data','spare'], @on_quickmode=false) ->
        super "dsuui-", "html/raid_create_dsu_ui.html", parent_selector
        for dsu in @vm.data_dsus
            @watch_dsu_checked dsu

    define_vm: (vm) =>
        vm.lang = lang.dsuui
        vm.data_dsus = @_gen_dsus "data"
        vm.spare_dsus = @_gen_dsus "spare"
        vm.active_index = 0
        vm.on_quickmode = @on_quickmode
        vm.disk_checkbox_click = @disk_checkbox_click
        vm.dsu_checkbox_click = @dsu_checkbox_click
        vm.data_enabled  = 'data' in @enabled
        vm.spare_enabled = 'spare' in @enabled
        vm.disk_list = @disk_list

    dsu_checkbox_click: (e) =>
        e.stopPropagation()
        
    disk_list: (disks)=>
        if disks.info == "none"
            return "空盘"
        else
            return @_translate(disks.info)
        
    _translate: (obj) =>
        status = ''
        health = {'normal':'正常', 'down':'下线', 'failed':'损坏'}
        role = {'data':'数据盘', 'spare':'热备盘', 'unused':'未使用', 'kicked':'损坏'}
        
        $.each obj, (key, val) ->
            switch key
                when 'cap_sector'
                    status += '容量: ' + fattr.cap(val)+ '<br/>'
                when 'health'
                    status += '健康: ' + health[val] + '<br/>'
                when 'role'
                    status += '状态: ' + role[val] + '<br/>'
                when 'raid'
                    if val.length > 0
                        status += '阵列: ' + val + '<br/>'
                    else
                        status += '阵列: 无'
        return status
        
    active_tab: (dsu_location) =>
        for dsu, i in @vm.data_dsus
            if dsu.location is dsu_location
                @vm.active_index = i

    disk_checkbox_click: (e) =>
        e.stopPropagation()
        location = $(e.target).data "location"
        if location
            dsutype = $(e.target).data "dsutype"
            [dsus, opp_dsus] = if dsutype is "data"\
                then [@vm.data_dsus, @vm.spare_dsus]\
                else [@vm.spare_dsus, @vm.data_dsus]
            dsu = @_find_dsu dsus, location
            opp_dsu = @_find_dsu opp_dsus, location
            @_uncheck_opp_dsu_disks dsu, opp_dsu
            @_count_dsu_checked_disks dsu
            @_count_dsu_checked_disks opp_dsu

           ### if dsutype is "data"
                @_calculatechunk dsu
            else
                @_calculatechunk opp_dsu
            $("#dsuui").change()       ###

    watch_dsu_checked: (dsu) =>
        dsu.$watch 'checked', () =>
            for col in dsu.disks
                for disk in col
                    if not disk.avail
                        continue
                    disk.checked = dsu.checked
            opp_dsu = @_get_opp_dsu dsu
            @_uncheck_opp_dsu_disks dsu, opp_dsu
            @_count_dsu_checked_disks dsu
            @_count_dsu_checked_disks opp_dsu

           # @_calculatechunk dsu
            #$("#dsuui").change()

    _calculatechunk: (dsu) =>
        @_count_dsu_checked_disks dsu
        nr = dsu.count
        if nr <= 0
            return "64KB"
        else if nr == 1
            return "256KB"
        else
            ck = 512 / (nr - 1)
            if ck > 16 and ck <= 32
                return "32KB"
            else if ck > 32 and ck <= 64
                return "64KB"
            else if ck > 64 and ck <= 128
                return "128KB"
            else if ck > 128
                return "256KB"

    getchunk:() =>
        chunk_value = []
        for dsu in @vm.data_dsus
            chunk_value.push  @_calculatechunk(dsu)
        return chunk_value[0]

    _count_dsu_checked_disks: (dsu) =>
        count = 0
        for col in dsu.disks
            for disk in col
                if disk.checked
                    count += 1
        dsu.count = count

    _uncheck_opp_dsu_disks: (dsu, opp_dsu) =>
        for col in dsu.disks
            for disk in col
                if disk.checked
                    opp_disk = @_find_disk [opp_dsu], disk.$model.location
                    opp_disk.checked = false

    get_disks: (type="data") =>
        dsus = if type is "data" then @vm.data_dsus else @vm.spare_dsus
        @_collect_checked_disks dsus

    _collect_checked_disks: (dsus) =>
        disks = []
        for dsu in dsus
            for col in dsu.disks
                for disk in col
                    disks.push(disk.location) if disk.checked
        return disks

    check_disks: (disks, type="data") =>
        dsus = if type is "data" then @vm.data_dsus else @vm.spare_dsus
        disks = if $.isArray(disks) then disks else [disks]
        for dsu in dsus
            for col in dsu.disks
                for disk in col
                    for checked in disks
                        if disk.location is checked.location
                            disk.checked = true
        for dsu in dsus
            @_count_dsu_checked_disks dsu

    _find_disk: (dsus, location) =>
        for dsu in dsus
            for col in dsu.disks
                for disk in col
                    if disk.$model.location is location
                        return disk

    _find_dsu: (dsus, location) =>
        for dsu in dsus
            for col in dsu.disks
                for disk in col
                    if disk.$model.location is location
                        return dsu

    _get_opp_dsu: (dsu) =>
        opp_dsus = if dsu.data then @vm.spare_dsus else @vm.data_dsus
        for opp_dsu in opp_dsus
            if opp_dsu.location is dsu.location
                return opp_dsu

    _tabid: (tabid_prefix, dsu) =>
        "#{tabid_prefix}_#{dsu.location.replace('.', '_')}"

    _gen_dsus: (prefix) =>
        return ({location: dsu.location, tabid: @_tabid(prefix, dsu), checked: false,\
            disks: @_gen_dsu_disks(dsu), count: 0, data: prefix is 'data'} for dsu in @sd.dsus.items)

    _belong_to_dsu: (disk, dsu) =>
        disk.location.indexOf(dsu.location) is 0

    _update_disk_status: (location, dsu) =>
        for disk in @sd.disks.items
            if disk.location is location and @_belong_to_dsu(disk, dsu) and disk.raid is "" and disk.health isnt "failed" and disk.role is "unused"
                return true
        return false
    
    _update_disk_info: (location, dsu) =>
        info = []
        for disk in @sd.disks.items
            if disk.location is location and @_belong_to_dsu(disk, dsu)
                info = health:disk.health, cap_sector:disk.cap_sector, role:disk.role, raid:disk.raid
                return info
        
        'none'
        
    _gen_dsu_disks: (dsu) =>
        disks = []

        for i in [1..4]
            cols = []
            for j in [0...dsu.support_disk_nr/4]
                location = "#{dsu.location}.#{j*4+i}"
                o = location: location, avail: false, checked: false, offline: false, info: ""
                o.avail = @_update_disk_status(location, dsu)
                o.info = @_update_disk_info(location, dsu)
                cols.push o
            disks.push cols

        return disks

    rendered: () =>
        super()

class RaidSetDiskRoleModal extends Modal
    constructor: (@sd, @page) ->
        super "raid-set-disk-role-modal-",\
            "html/raid_set_disk_role_modal.html",\
            style: "min-width:670px;"
        @raid = null

    define_vm: (vm) =>
        vm.lang = lang.raid_set_disk_role_modal
        vm.raid_options = subitems @sd.raids.items, name:""
        vm.role = "global_spare"
        vm.submit = @submit
        vm.select_visible = false

        vm.$watch "role", =>
            vm.select_visible = if vm.role == "global_spare" then false else true

    rendered: () =>
        super()
        @dsuui = new RaidCreateDSUUI(@sd, "#dsuui", ['spare'])
        @dsuui.attach()
        @add_child @dsuui
        $("input:radio").uniform()
        $("#raid-select").chosen()

        $.validator.addMethod("min-spare-disks", (val, element) =>
            nr = @dsuui.get_disks("spare").length
            return if nr is 0 then false else true)

        $("form.raid").validate(
            valid_opt(
                rules:
                    "spare-disks-checkbox":
                        "min-spare-disks": true
                messages:
                    "spare-disks-checkbox":
                        "min-spare-disks": "至少需要1块热备盘"))

    submit: () =>
        raid = null
        if @vm.select_visible
            chosen = $("#raid-select")
            raid = chosen.val()
        @set_disk_role @dsuui.get_disks("spare"), @vm.role, raid

    set_disk_role: (disks, role, raid) =>
        chain = new Chain
        for disk in disks
            chain.chain @_each_set_disk_role(disk, role, raid)
        @hide()
        show_chain_progress(chain).done =>
            @page.attach()

    _each_set_disk_role: (disk, role, raid) =>
        return () => (new DiskRest @sd.host).set_disk_role disk, role, raid

class RaidCreateModal extends Modal
    constructor: (@sd, @page) ->
        super "raid-create-modal-", "html/raid_create_modal.html", style: "min-width:670px;"

    define_vm: (vm) =>
        vm.lang = lang.raid_create_modal
        vm.name = ""
        vm.level = "5"
        #vm.chunk = "64KB"
        vm.rebuild_priority = "low"
        vm.sync = false
        vm.submit = @submit

    rendered: () =>
        super()
        @dsuui = new RaidCreateDSUUI(@sd, "#dsuui")
        @dsuui.attach()
        @add_child @dsuui
        $("input:radio").uniform()
        $(".basic-toggle-button").toggleButtons()
        $("#sync").change =>
            @vm.sync = $("#sync").prop "checked"

        dsu = @prefer_dsu_location()
        [raids...] = (disk for disk in @sd.disks.items\
                                when disk.role is 'unused'\
                                and disk.location.indexOf(dsu) is 0)
        [cap_sector...] = (raid.cap_sector for raid in raids)
        total = []
        cap_sector.sort()
        for i in [0...cap_sector.length]
            count = 0
            for j in [0...cap_sector.length]
                if cap_sector[i] is cap_sector[j]
                    count++
            total.push([cap_sector[i],count])
            i+=count
            
        for k in [0...total.length]
            if total[k][1] >= 3
                [Raids...] = (disk for disk in raids\
                                when disk.cap_sector is total[k][0])
                for s in [0...3]
                    @dsuui.check_disks Raids[s]
                    @dsuui.active_tab dsu
                #@dsuui.check_disks Raids[3], "spare"
                break
                
        $.validator.addMethod("min-raid-disks", (val, element) =>
            level = parseInt @vm.level
            nr = @dsuui.get_disks().length
            if level is 5 and nr < 3
                return false
            else if level is 0 and nr < 1
                return false
            else if level is 1 and nr isnt 2
                return false
            else if level is 10 and nr%2 != 0  and nr > 0
                return false
            else
                return true
        ,(params, element) =>
            level = parseInt @vm.level
            nr = @dsuui.get_disks().length
            if level is 5 and nr < 3
                return "级别5阵列最少需要3块磁盘"
            else if level is 0 and nr < 1
                return "级别0阵列最少需要1块磁盘"
            else if level is 1 and nr != 2
                return "级别1阵列仅支持2块磁盘"
            else if level is 10 and nr%2 != 0 and nr > 0
                return "级别10阵列数据盘必须是偶数个"
        )
        $.validator.addMethod("spare-disks-support", (val, element) =>
            level = parseInt @vm.level
            nr = @dsuui.get_disks("spare").length
            if level is 0 and nr > 0
                return false
            else if level is 10 and nr > 0
                return false
            else
                return true
        ,(params, element) =>
            level = parseInt @vm.level
            nr = @dsuui.get_disks("spare").length
            if level is 0 and nr > 0
                return '级别0阵列不支持热备盘'
            else if level is 10 and nr > 0
                return '级别10阵列不支持热备盘'
        )
        $.validator.addMethod("min-cap-spare-disks", (val, element) =>
            level = parseInt @vm.level
            if level != 5
                return true
            map = {}
            for disk in @sd.disks.items
                map[disk.location] = disk

            spare_disks = (map[loc] for loc in @dsuui.get_disks("spare"))
            data_disks = (map[loc] for loc in @dsuui.get_disks())
            min_cap = Math.min.apply(null, (d.cap_sector for d in data_disks))
            for s in spare_disks
                if s.cap_sector < min_cap
                    return false
            return true
        , "热备盘容量太小"
        )
        
        $("form.raid").validate(
            valid_opt(
                rules:
                    name:
                        required: true
                        regex: "^[_a-zA-Z][-_a-zA-Z0-9]*$"
                        duplicated: @sd.raids.items
                        maxlength: 64
                    "raid-disks-checkbox":
                        "min-raid-disks": true
                        maxlength: 24
                    "spare-disks-checkbox":
                        "spare-disks-support": true
                        "min-cap-spare-disks": true
                messages:
                    name:
                        required: "请输入阵列名称"
                        duplicated: "阵列名称已存在"
                        maxlength: "阵列名称长度不能超过64个字母"
                    "raid-disks-checkbox":
                        maxlength: "阵列最多支持24个磁盘"))

    submit: () =>
        if $("form.raid").validate().form()
            @create(@vm.name, @vm.level, @dsuui.getchunk(), @dsuui.get_disks(),\
                @dsuui.get_disks("spare"), @vm.rebuild_priority, @vm.sync)

    create: (name, level, chunk, raid_disks, spare_disks, rebuild, sync) =>
        @page.frozen()
        raid_disks = raid_disks.join ","
        spare_disks = spare_disks.join ","
        chain = new Chain
        chain.chain(=> (new RaidRest(@sd.host)).create(name: name, level: level,\
            chunk: chunk, raid_disks: raid_disks, spare_disks:spare_disks,\
            rebuild_priority:rebuild, sync:sync, cache:''))
            .chain @sd.update("raids")

        @hide()
        show_chain_progress(chain).done =>
            @page.attach()

    count_dsu_disks: (dsu) =>
        return (disk for disk in @sd.disks.items\
                         when disk.role is 'unused'\
                         and disk.location.indexOf(dsu.location) is 0).length

    prefer_dsu_location: () =>
        for dsu in @sd.dsus.items
            if @count_dsu_disks(dsu) >= 3
                return dsu.location
        return if @sd.dsus.length then @sd.dsus.items[0].location else '_'

class VolumeDeleteModal extends ResDeleteModal
    constructor: (@sd, page, res) ->
        super "volume-delete-", page, res, lang.volume_delete_modal

    _submit: (deleted) =>
        @page.frozen()
        chain = new Chain
        chain.chain($.map(deleted, (v) => (=> (new VolumeRest(@sd.host)).delete v)))
            .chain @sd.update('volumes')
        return chain

class VolumeCreateModal extends Modal
    constructor: (@sd, @page) ->
        super "volume-create-modal-", "html/volume_create_modal.html"

    define_vm: (vm) =>
        @_settings = new (require("settings").Settings)
        vm.lang = lang.volume_create_modal
        vm.volume_name = ""
        vm.raid_options = @raid_options()
        vm.raid = $.extend {}, @sd.raids.items[0]
        vm.fattr_cap_usage = fattr.cap_usage
        vm.cap = sector_to_gb(vm.raid.cap_sector-vm.raid.used_cap_sector)
        vm.unit = "GB"
        vm.automap = false
        vm.initr_wwn = ""
        vm.submit = @submit

        vm.$watch "raid",=>
            if vm.unit == "MB"
                vm.cap = sector_to_mb(vm.raid.cap_sector-vm.raid.used_cap_sector)
            else if vm.unit =="GB"
                vm.cap = sector_to_gb(vm.raid.cap_sector-vm.raid.used_cap_sector)
            else
                vm.cap = sector_to_tb(vm.raid.cap_sector-vm.raid.used_cap_sector)
        vm.$watch "unit",=>
            if vm.unit == "MB"
                vm.cap = sector_to_mb(vm.raid.cap_sector-vm.raid.used_cap_sector)
            else if vm.unit =="GB"
                vm.cap = sector_to_gb(vm.raid.cap_sector-vm.raid.used_cap_sector)
            else
                vm.cap = sector_to_tb(vm.raid.cap_sector-vm.raid.used_cap_sector)

        vm.$watch "volume_name", =>
            vm.initr_wwn = "#{prefix_wwn}:#{vm.volume_name}"

    rendered: () =>
        super()
        $("input:radio").uniform()
        $(".basic-toggle-button").toggleButtons()
        $("#raid-select").chosen()
        $("#automap").change =>
            @vm.automap = $("#automap").prop "checked"
        chosen = $("#raid-select")
        chosen.change =>
            @vm.raid = $.extend {}, @sd.raids.get(chosen.val())
            $("form.volume").validate().element $("#cap")

        $.validator.addMethod("capacity", (val, elem) =>
            free_cap = @vm.raid.cap_sector - @vm.raid.used_cap_sector
            alloc_cap = cap_to_sector @vm.cap, @vm.unit
            if alloc_cap < mb_to_sector(1024)
                return false
            else if alloc_cap > free_cap
                return false
            else
                return true
        ,(params, elem) =>
            free_cap = @vm.raid.cap_sector - @vm.raid.used_cap_sector
            alloc_cap = cap_to_sector @vm.cap, @vm.unit
            if alloc_cap < mb_to_sector(1024)
                return "虚拟磁盘最小容量必须大于等于1024MB"
            else if alloc_cap > free_cap
                return "分配容量大于阵列的剩余容量"
        )
        
        $("form.volume").validate(
            valid_opt(
                rules:
                    name:
                        required: true
                        regex: '^[_a-zA-Z][-_a-zA-Z0-9]*$'
                        duplicated: @sd.volumes.items
                        maxlength: 64
                    capacity:
                        required: true
                        regex: "^\\d+(\.\\d+)?$"
                        capacity: true
                    wwn:
                        required: true
                        regex: '^(iqn.2013-01.net.zbx.initiator:)+[_a-zA-Z0-9]*$'
                        maxlength: 96  
                messages:
                    name:
                        required: "请输入虚拟磁盘名称"
                        duplicated: "虚拟磁盘名称已存在"
                        maxlength: "虚拟磁盘名称长度不能超过64个字母"
                    capacity:
                        required: "请输入虚拟磁盘容量"
                    wwn:
                        required: "请输入客户端名称"
                        maxlength: "客户端名称长度不能超过96个字母"))

    raid_options: () =>
        raids_availble = []
        raids = subitems @sd.raids.items, id:"", name:"", health: "normal"
        for i in raids
            if i.health == "normal"
                raids_availble.push i
        return raids_availble
        
    submit: () =>
        if $("form.volume").validate().form()
            @create(@vm.volume_name, @vm.raid.name, "#{@vm.cap}#{@vm.unit}", @vm.automap, @vm.initr_wwn)
            if @_settings.sync
                @sync(@vm.volume_name)

    create: (name, raid, cap, automap, wwn) =>
        @page.frozen()
        chain = new Chain
        chain.chain => (new VolumeRest(@sd.host)).create name: name, raid: raid, capacity: cap
        if automap
            if not @sd.initrs.get wwn
                for n in @sd.networks.items
                    if n.link and n.ipaddr isnt ""
                        portals = n.iface
                        break
                chain.chain => (new InitiatorRest(@sd.host)).create wwn:wwn, portals:portals
            chain.chain => (new InitiatorRest(@sd.host)).map wwn, name
        chain.chain @sd.update('volumes')

        @hide()
        show_chain_progress(chain).done =>
            @page.attach()

    sync: (name) =>
        @page.frozen()
        chain = new Chain()
        chain.chain => 
            (new SyncConfigRest(@sd.host)).sync_enable(name)
            
        @hide()
        show_chain_progress(chain).done =>
            @page.attach()

class InitrDeleteModal extends ResDeleteModal
    constructor: (@sd, page, res) ->
        super "initr-delete-", page, res, lang.initr_delete_modal

    _submit: (deleted) =>
        @page.frozen()
        chain = new Chain
        chain.chain($.map(deleted, (v) => (=> (new InitiatorRest(@sd.host)).delete v)))
        chain.chain @sd.update('initrs')
        return chain

class InitrCreateModal extends Modal
    constructor: (@sd, @page) ->
        super "initr-create-modal-", "html/initr_create_modal.html"
        @vm.show_iscsi = if @_iscsi.iScSiAvalable() and !@_settings.fc then true else false
        
    define_vm: (vm) =>
        @_settings = new (require("settings").Settings)
        @_iscsi = new IScSiManager
        vm.portals = @subitems()
        vm.lang = lang.initr_create_modal
        vm.initr_wwn = @_genwwn()
        vm.initr_wwpn = @_genwwpn()
        vm.show_iscsi = @show_iscsi
        
        vm.submit = @submit

        $(@sd.networks.items).on "updated", (e, source) =>
            @vm.portals = @subitems()

    subitems: () =>
        items = subitems @sd.networks.items,id:"",ipaddr:"",iface:"",netmask:"",type:"",checked:false
        removable = []
        if not @_able_bonding()
            for eth in items
                removable.push eth if eth.type isnt "bond-slave"
            return removable
        items

    _able_bonding: =>
        for eth in @sd.networks.items
            return false if (eth.type.indexOf "bond") isnt -1
        true

    _genwwn:  () ->
        wwn_prefix = 'iqn.2013-01.net.zbx.initiator'
        s1 = Math.floor((1 + Math.random()) * 0x10000).toString(16).substring(1)
        s2 = Math.floor((1 + Math.random()) * 0x10000).toString(16).substring(1)
        s3 = Math.floor((1 + Math.random()) * 0x10000).toString(16).substring(1)
        "#{wwn_prefix}:#{s1}#{s2}#{s3}"

    _genwwpn:  () ->
        s = Math.floor((1 + Math.random()) * 0x10000).toString(16).substring(3)
        for i in [1..7]
            s1 = Math.floor((1 + Math.random()) * 0x10000).toString(16).substring(3)
            s = "#{s}:#{s1}"
        return s

    rendered: () =>
        super()
        $("form.initr").validate(
            valid_opt(
                rules:
                    wwpn:
                        required: true
                        regex: '^([0-9a-z]{2}:){7}[0-9a-z]{2}$'
                        duplicated: @sd.initrs.items
                        maxlength: 96
                    wwn:
                        required: true
                        regex: '^(iqn.2013-01.net.zbx.initiator:)(.*)$'
                        duplicated: @sd.initrs.items
                        maxlength: 96
                    'eth-checkbox':
                        required: !@_settings.fc
                        minlength: 1
                messages:
                    wwpn:
                        required: "请输入客户端名称"
                        duplicated: "客户端名称已存在"
                        maxlength: "客户端名称长度不能超过96个字母"
                    wwn:
                        required: "请输入客户端名称"
                        duplicated: "客户端名称已存在"
                        maxlength: "客户端名称长度不能超过96个字母"
                    'eth-checkbox': "请选择至少一个网口"))

    submit: () =>
        if $("form.initr").validate().form()
            portals = []
            for i in @vm.portals when i.checked
                portals.push i.$model.iface
            if @_settings.fc
                @create @vm.initr_wwpn, portals=""
            else
                @create @vm.initr_wwn, portals.join(",")

    create: (wwn, portals) =>
        @page.frozen()
        chain = new Chain
        chain.chain => (new InitiatorRest(@sd.host)).create wwn:wwn, portals:portals
        chain.chain @sd.update('initrs')

        @hide()
        show_chain_progress(chain).done =>
            @page.attach()

class VolumeMapModal extends Modal
    constructor: (@sd, @page, @initr) ->
        super "volume-map-modal-", "html/volume_map_modal.html"

    define_vm: (vm) =>
        vm.volumes = @subitems()
        vm.lang = lang.volume_map_modal
        vm.all_checked = false
        vm.submit = @submit

        vm.$watch "all_checked", =>
            for v in vm.volumes
                v.checked = vm.all_checked

    rendered: () =>
        super()
        $("form.map-volumes").validate(
            valid_opt(
                rules:
                    'volume-checkbox':
                        required: true
                        minlength: 1
                messages:
                    'volume-checkbox': "请选择至少一个虚拟磁盘"))
        
    submit: () =>
        if $("form.map-volumes").validate().form()
            selecteds = []
            for i in @vm.volumes when i.checked
                selecteds.push i.$model.name
            @map @initr.wwn, selecteds

    subitems: () =>
        volumes_available = []
        items = subitems @sd.spare_volumes(), id:"", name:"", health:"", cap_sector:"",\
             checked:false
        for i in items
            if i.health == "normal"
                volumes_available.push i
        
        return volumes_available

    map: (wwn, volumes) =>
        @page.frozen()
        chain = new Chain
        for volume in volumes
            chain.chain @_eachMap(wwn, volume)
        chain.chain @sd.update('initrs')

        @hide()
        show_chain_progress(chain).done =>
            @page.attach()
    
    _eachMap: (wwn, volume) =>
        return ()=> (new InitiatorRest @sd.host).map wwn, volume

class VolumeUnmapModal extends Modal
    constructor: (@sd, @page, @initr) ->
        super "volume-unmap-modal-", "html/volume_map_modal.html"

    define_vm: (vm) =>
        vm.volumes = @subitems()
        vm.lang = lang.volume_unmap_modal
        vm.all_checked = false
        vm.submit = @submit

        vm.$watch "all_checked", =>
            for v in vm.volumes
                v.checked = vm.all_checked

    rendered: () =>
        super()
        $("form.map-volumes").validate(
            valid_opt(
                rules:
                    'volume-checkbox':
                        required: true
                        minlength: 1
                messages:
                    'volume-checkbox': "请选择至少一个虚拟磁盘"))
        
    submit: () =>
        if $("form.map-volumes").validate().form()
            selecteds = []
            for i in @vm.volumes when i.checked
                selecteds.push i.$model.name
            @unmap @initr.wwn, selecteds

    subitems: () =>
        items = subitems @sd.initr_volumes(@initr), id:"", name:"", health:"", cap_sector:"",\
             checked:false

    unmap: (wwn, volumes) =>
        @page.frozen()
        chain = new Chain
        for volume in volumes
            chain.chain @_eachunmap(wwn,volume)
        chain.chain @sd.update('initrs')

        @hide()
        show_chain_progress(chain).done =>
            @page.attach()
     
    _eachunmap: (wwn,volume) =>
        return () => (new InitiatorRest(@sd.host)).unmap wwn, volume
        
class EthBondingModal extends Modal
    constructor: (@sd, @page) ->
        super "Eth-bonding-modal-", "html/eth_bonding_modal.html"

    define_vm: (vm) =>
        vm.lang = lang.eth_bonding_modal
        vm.options = [
          { key: "负载均衡模式", value: "balance-rr" }
          { key: "主备模式", value: "active-backup" }
        ]
        vm.submit = @submit
        vm.ip = ""
        vm.netmask = "255.255.255.0"

    rendered: =>
        super()

        $("#eth-bonding").chosen()

        Netmask = require("netmask").Netmask
        $.validator.addMethod("validIP", (val, element) =>
            regex = /^\d{1,3}(\.\d{1,3}){3}$/
            if not regex.test val
                return false
            try
                n = new Netmask @vm.ip, @vm.netmask
                return true
            catch error
                return false
        )
        $("form.eth-bonding").validate(
            valid_opt(
                rules:
                    ip:
                        required: true
                        validIP: true
                    netmask:
                        required: true
                        validIP: true
                messages:
                    ip:
                        required: "请输入IP地址"
                        validIP: "无效IP地址"
                    netmask:
                        required: "请输入子网掩码"
                        validIP: "无效子网掩码"))

    submit: =>
        if $("form.eth-bonding").validate().form()
            @page.frozen()
            @page.dview.reconnect = true
            chain = new Chain
            chain.chain =>
                selected = $("#eth-bonding").val()
                rest = new NetworkRest @sd.host
                rest.create_eth_bonding @vm.ip, @vm.netmask, selected

            @hide()
            show_chain_progress(chain, true).fail =>
                index = window.adminview.find_nav_index @page.dview.menuid
                window.adminview.remove_tab index if index isnt -1
                ###
                @page.settings.removeLoginedMachine @page.dview.host
                @sd.close_socket()
                arr_remove sds, @sd
                @page.attach()
                @page.dview.switch_to_login_page()
                ###

class FsCreateModal extends Modal
    constructor: (@sd, @page, @volname) ->
        super "fs-create-modal-", "html/fs_create_modal.html"

    define_vm: (vm) =>
        vm.mount_dirs = @subitems()
        vm.lang = lang.fs_create_modal
        vm.submit = @submit

    rendered: () =>
        super()
        $("form.fs").validate(
            valid_opt(
                rules:
                    'dir-checkbox':
                        required: true
                        maxlength: 1
                messages:
                    'dir-checkbox': "请选择一个目录作为挂载点"))

    subitems: () =>
        items = []
        used_names=[]

        for fs_o in @sd.filesystem.data
            used_names.push fs_o.name
        for i in [1..2]
            name = "myfs#{i}"
            if name in used_names
                o = path:"/share/vol#{i}", used:true, checked:false, fsname:name
            else
                o = path:"/share/vol#{i}", used:false, checked:false, fsname:name
            items.push o
        return items

    submit: () =>
        if $("form.fs").validate().form()
            dir_to_mount = ""

            for dir in @vm.mount_dirs when dir.checked
                dir_to_mount =  dir.fsname
            @enable_fs dir_to_mount

    enable_fs: (dir) =>
        if dir==''
            @hide()
            (new MessageModal(lang.volume_warning.over_max_fs)).attach()
        else
            @page.frozen()
            chain = new Chain()
            chain.chain(=> (new FileSystemRest(@sd.host)).create_cy dir, @volname)
                .chain @sd.update("filesystem")
            @hide()
            show_chain_progress(chain).done =>
                @page.attach()

class FsChooseModal extends Modal
    constructor: (@sd, @page, @fsname, @volname) ->
        super "fs-choose-modal-", "html/fs_choose_modal.html"

    define_vm: (vm) =>
        vm.filesystems = @subitems()
        vm.lang = lang.fs_choose_modal
        vm.submit = @submit

    rendered: () =>
        super()
        $("form.filesystems").validate(
            valid_opt(
                rules:
                    'fs-checkbox':
                        required: true
                        maxlength: 1
                messages:
                    'fs-checkbox': "请选择一个文件系统类型"))

    subitems: () =>
        items = []
        o = used:true, checked:false, type:"monfs", fsname:"视频文件系统"
        items.push o
        o = used:true, checked:false, type:"xfs", fsname:"通用文件系统"
        items.push o
        return items

    submit: () =>
        if $("form.filesystems").validate().form()
            fs_type = ""
            for filesystem in @vm.filesystems when filesystem.checked
                fs_type =  filesystem.type

            @enable_fs fs_type

    enable_fs: (fs_type) =>
        @page.frozen()
        chain = new Chain()
        chain.chain(=> (new FileSystemRest(@sd.host)).create @fsname, fs_type, @volname)
            .chain @sd.update("filesystem")
        @hide()
        show_chain_progress(chain).done =>
            @page.attach()
            
#####################################################################

class CentralCreateServerModal extends Modal
    constructor: (@sd, @page) ->
        super "central-server-modal-", "html/central_create_server_modal.html"
        
    define_vm: (vm) =>
        vm.lang = lang.central_modal
        vm.submit = @submit
        vm.ip = ""
        vm.size = "4U"
        vm.version = "ZS2000"
        vm.type = "服务器"
        vm.close_alert = @close_alert
        
    rendered: () =>
        super()
        $(".basic-toggle-button").toggleButtons()
        $("form.server").validate(
            valid_opt(
                rules:
                    ip:
                        required: true
                messages:
                    ip:
                        required: "请输入ip地址"))
                        
    close_alert: (e) =>
        $(".alert-error").hide()
        
    _check: () =>
        for i in @sd.clouds.items
            if i.devtype is "export"
                if @vm.ip is i.ip
                    $('.alert-error', $('.server')).show()
                    return false
        return true
    submit: () =>
        if @_check()
            if $("form.server").validate().form()
                query = (new MachineRest(@sd.host))
                machine_detail = query.add @vm.ip,'export'
                machine_detail.done (data) =>
                    if data.status is 'success'
                        @page.frozen()
                        chain = new Chain
                        chain.chain => (new MachineRest(@sd.host)).add @vm.ip,'export'
                        chain.chain @sd.update('all')
                        @hide()
                        show_chain_progress(chain).done =>
                            @page.attach()
                            (new MessageModal(lang.central_modal.success)).attach()
                    else
                        (new MessageModal lang.central_modal.error).attach()
                    
class CentralCreateStoreModal extends Modal
    constructor: (@sd, @page, @message) ->
        super "central-worker-modal-", "html/central_create_store_modal.html"
        @store_ip = ""
        
    define_vm: (vm) =>
        vm.lang = lang.central_modal
        vm.submit = @submit
        vm.message = @message
        vm.number_ip = ""
        vm.start_ip = "192.168.2."
        vm.check_info = @check_info
        vm.fattr_process = fattr.process
        vm.fattr_process_step = fattr.process_step
        vm.worker_ip = ''
        vm.ips = ''
        vm.option = "auto"
        vm.text_ip = ""
        vm.close_alert = @close_alert
    subitems: () =>
        ips = [{"ip":"","session":false,"name":"mysql","checked":false,"option":"no"}]
        ips
    rendered: () =>
        super()
        $("#myTab li:eq(0) a").tab "show"
        $("form.docker").validate(
            valid_opt(
                rules:
                    start_ip:
                        required: true
                    number_ip:
                        regex: '^[0-9]*$'
                        required: true
                messages:
                    start_ip:
                        required: "请输入起始ip"
                    number_ip:
                        required: "请输入ip个数"))
        
        $("form.dockers").validate(
            valid_opt(
                rules:
                    text_ip:
                        required: true
                messages:
                    text_ip:
                        required: "请输入需要添加的ip"))
    check_info: (i) =>
        if i is 0
            $("#myTab li:eq(0) a").tab "show"
        if i is 1
            if @vm.option is 'auto'
                $("#myTab li:eq(1) a").tab "show"
            else
                $("#myTab li:eq(2) a").tab "show"
        if i is 2
            $(".alert-error").hide()
            if @vm.option is 'auto'
                $("#myTab li:eq(1) a").tab "show"
            else
                $("#myTab li:eq(2) a").tab "show"
        if i is 3
            if @vm.option is 'auto'
                if $("form.docker").validate().form()
                    $("#myTab li:eq(3) a").tab "show"
                    @change_ip('auto')
            else
                if $("form.dockers").validate().form()
                    $("#myTab li:eq(3) a").tab "show"
                    @change_ip('manual')
                    
    change_ip: (type) =>
        ips = []
        new_ips = []
        
        if type is 'auto'
            a = @vm.start_ip.split('.')
            number_ip = parseInt @vm.number_ip
            start_ip = parseInt a[3]
            for i in [start_ip...start_ip + number_ip]
                ip = '192.168.2.' + i
                ips.push ip
        else
            ips = @vm.text_ip.split(',')
            
        if ips.length >= 4
            p = 0
            for o in ips
                if p < 2
                    new_ips.push o
                else if p is 2
                    new_ips.push "...."
                else if p is ips.length - 1
                    new_ips.push o
                p++
            new_ips = new_ips.join ","
            @vm.ips = new_ips
        else
            @vm.ips = ips
            
        @store_ip = ips
        
    close_alert: (e) =>
        $(".alert-error").hide()
        
    _check: () =>
        for i in @sd.clouds.items
            if i.devtype is "storage"
                if i.ip in @store_ip
                    $('.alert-error', $('.dockers')).show()
                    return false
        return true
                
    submit: () =>
        if @_check()
            for i in @store_ip
                @page.frozen()
                chain = new Chain
                chain.chain => (new MachineRest(@sd.host)).add i,'storage'
                chain.chain @sd.update('all')
                @hide()
                show_chain_progress(chain).done =>
            @page.attach()
            (new MessageModal(lang.central_modal.success)).attach()
                        
class CentralCreateClientModal extends Modal
    constructor: (@sd, @page) ->
        super "central-client-modal-", "html/central_create_client_modal.html"

    define_vm: (vm) =>
        vm.lang = lang.central_modal
        vm.submit = @submit
        vm.ip = ""
        vm.size = "4U"
        vm.version = "ZS2000"
        vm.type = "客户端"
        vm.close_alert = @close_alert
        
    rendered: () =>
        super()
        $(".basic-toggle-button").toggleButtons()
        $("form.client").validate(
            valid_opt(
                rules:
                    ip:
                        required: true
                messages:
                    ip:
                        required: "请输入ip地址"))
                        
    close_alert: (e) =>
        $(".alert-error").hide()
        
    _check: () =>
        for i in @sd.clouds.items
            if i.devtype is "client"
                if @vm.ip is i.ip
                    $('.alert-error', $('.client')).show()
                    return false
        return true
        
    submit: () =>
        if @_check()
            if $("form.client").validate().form()
                query = (new MachineRest(@sd.host))
                machine_detail = query.add @vm.ip,'client'
                machine_detail.done (data) =>
                    if data.status is 'success'
                        @page.frozen()
                        chain = new Chain
                        chain.chain => (new MachineRest(@sd.host)).add @vm.ip,'client'
                        chain.chain @sd.update('all')
                        @hide()
                        show_chain_progress(chain).done =>
                            @page.attach()
                            (new MessageModal(lang.central_modal.success)).attach()
                    else
                        (new MessageModal lang.central_modal.error).attach()
                        
class CentralExpandModal extends Modal
    constructor: (@sd, @page, @message) ->
        super "central-worker-modal-", "html/central_expand_modal.html"
        @tips = ""
        @machine = ""
        
    define_vm: (vm) =>
        vm.lang = lang.central_modal
        vm.submit = @submit
        vm.message = @message
        vm.options = @options()
        vm.store = @count_machines()
        vm.next = @next
        vm.fattr_process_step = fattr.process_step
        vm.all_checked = false
        vm.tips = @tips
        vm.$watch "all_checked", =>
            for r in vm.store
                r.checked = vm.all_checked
                
    rendered: () =>
        super()
        $("#myTab li:eq(0) a").tab "show"
        $("#node").chosen()
        
    subitems: () =>
        sub = []
        items = subitems @sd.clouds.items,cid:"",devtype:"",expand:"",export:"",ip:"",status:"", uuid:"", checked:false
        ((sub.push i) for i in items when i.devtype is 'storage')
        sub
        
    count_options: () =>
        sub = []
        ((sub.push i) for i in @subitems() when i.export is @message)
        sub
        
    count_machines: () =>
        sub = []
        ((sub.push i) for i in @subitems() when i.status is false)
        sub
        ###
        sub = []
        items = subitems @sd.clouds.items,cid:"",devtype:"",expand:"",export:"",ip:"",status:"", uuid:"", checked:false
        ((sub.push i) for i in items when i.devtype is 'storage')
        sub###
        
    options: () =>
        option = [0]
        options = []
        
        ((option.push i.cid) for i in @count_options() when i.cid not in option)
        max = Math.max.apply(null,option)
        if max is 0
            [{key:1,value:"1"}]
        else
            ((options.push {key:i,value:i.toString()}) for i in [1..max + 1])
            options
            
    next: (i) =>
        if i is 0
            $("#myTab li:eq(0) a").tab "show"
        if i is 1
            $("#myTab li:eq(1) a").tab "show"
        if i is 2
            if @_tips()
                $("#myTab li:eq(2) a").tab "show"
            else
                (new MessageModal(lang.central_modal.choose)).attach()
                
    _tips: () =>
        selected = $("#node").val()
        machine = []
        ((machine.push i.ip) for i in @vm.store when i.checked)
        @machine = machine.join ","
        if @machine
            @vm.tips = "确认要将以下机器#{@machine}添加到节点#{selected}吗?"
            true
            
       
    submit: () => 
        #selected = $("#node").val()
        machine = []
        ((machine.push i.ip) for i in @vm.store when i.checked)
        #@monitor(machine)
        @machine = machine.join ","
        
        @page.frozen()
        chain = new Chain
        chain.chain => (new MachineRest(@sd.host)).export @message,@machine
        chain.chain @sd.update('all')
        @hide()
        show_chain_progress(chain).done =>
            @page.attach()
            (new MessageModal(lang.central_modal.expand_success)).attach()
        
    monitor: (machine) =>
        for i in machine
            query = (new MachineRest(@sd.host))
            machine_detail = query.monitor "a", i, 24, "storage"
            
        for j in @sd.centers.items
            if j.Devtype is "export" and j.Ip is @message
                return
        machine_detail = query.monitor "a", @message, 24, "export"
        
class CentralStartModal extends Modal
    constructor: (@sd, @page, @message) ->
        super "central-server-modal-", "html/central_start_modal.html"
        
    define_vm: (vm) =>
        vm.lang = lang.central_modal
        vm.submit = @submit
        vm.message = @message
        vm.fattr_server_health = fattr.server_health
        vm.node = @node()
        vm.all_checked = false
        vm.start = @start
        vm.stop = @stop
        vm.$watch "all_checked", =>
            for r in vm.store
                r.checked = vm.all_checked
                
    rendered: () =>
        super()
        @vm.node = @node()
        @data_table = $("#start-table").dataTable dtable_opt(retrieve: true)
        $(".dataTables_filter input").addClass "m-wrap small"
        $(".dataTables_length select").addClass "m-wrap small"
                
    subitems: () =>
        sub = []
        items = subitems @sd.clouds.items,cid:"",devtype:"",expand:"",export:"",ip:"",status:"", uuid:"", checked:false
        ((sub.push i)for i in items when i.devtype is 'storage' and i.export is @message)
        sub
        
    node: () =>
        option = [0]
        options = []
        ((option.push i.cid )for i in @subitems() when i.cid not in option)
        max = Math.max.apply(null,option)
        if max is 0
            options
        else
            for i in [1..max]
                options.push {cid:i}
            for i in @subitems()
                for j in options
                    if i.cid is j.cid
                        j.status = i.status
            options
            
    start: (cid) =>
        @page.frozen()
        chain = new Chain
        chain.chain => (new MachineRest(@sd.host)).storage @message,cid
        chain.chain @sd.update('all')
        @hide()
        show_chain_progress(chain).done =>
            @page.attach()
            (new MessageModal(lang.central_modal.start_success)).attach()
            
    stop: (cid) =>
        ip = []
        ((ip.push i.ip )for i in @subitems() when i.cid is cid)
        ip = ip.join ","
        
        @page.frozen()
        chain = new Chain
        chain.chain => (new MachineRest(@sd.host)).rozostop 'storage',ip
        chain.chain @sd.update('all')
        @hide()
        show_chain_progress(chain).done =>
            @page.attach()
            (new MessageModal(lang.central_modal.stop_success)).attach()
            
class CentralDownloadLogModal extends Modal
    constructor: (@sd, @page) ->
        super "central-server-modal-", "html/central_downloadlog_modal.html"
        
    define_vm: (vm) =>
        vm.lang = lang.central_warning
        vm.submit = @submit
        vm.ip = ""
                
    rendered: () =>
        super()
                
    submit: () =>
        @page.frozen()
        chain = new Chain
        chain.chain => (new MachineRest(@sd.host)).download_log @vm.ip
        chain.chain @sd.update('all')
        show_chain_progress(chain).done =>
            console.log 123
        
class CentralManualModal extends Modal
    constructor: (@sd, @page) ->
        super "central-server-modal-", "html/central_manual_modal.html"
        
    define_vm: (vm) =>
        vm.lang = lang.central_manual
        vm.submit = @submit
        vm.ip = ""
        vm.options = [
          { key: "存储", value: "storage" }
          { key: "元数据", value: "export" }
        ]
    rendered: () =>
        super()
        $("#manual").chosen()
        
    count_machine: (selected) =>
        if selected is "export"
            for i in @sd.centers.items
                if i.Devtype is "export"
                    (new MessageModal @vm.lang.add_server_error).attach()
                    return false
        else
            for i in @sd.centers.items
                if i.Devtype is "storage" and i.Ip is @vm.ip
                    (new MessageModal @vm.lang.add_store_error).attach()
                    return false
        return true
        
    submit: () =>
        if $("form.manual").validate().form()
            selected = $("#manual").val()
            if @count_machine(selected)
                @page.frozen()
                chain = new Chain
                chain.chain => (new MachineRest(@sd.host)).monitor "a", @vm.ip, 24, selected
                chain.chain @sd.update('all')
                @hide()
                show_chain_progress(chain).done (data)=>
                    (new MessageModal lang.central_search_modal.monitor_success).attach()
                    #@tips(@vm.ip)
                    @page.attach()
                .fail =>
                    (new MessageModal lang.central_search_modal.monitor_error).attach()
            
    tips:(ip) =>
        try
            datas = {}
            datas[ip] = 0
            ((datas[ip] = datas[ip] + 1 )for j in @sd.stores.items.journals when j.ip is ip)
            if datas[ip] > 0
                if @type is "storage"
                    types = "存储"
                else
                    types = "元数据"
                @show_tips(ip,datas[ip],types)
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

class CentralAddEmailModal extends Modal
    constructor: (@sd, @page) ->
        super "central-add-email-modal-", "html/central_add_email_modal.html"
        
    define_vm: (vm) =>
        vm.lang = lang.central_email
        vm.submit = @submit
        vm.email = ""
        vm.level = ""
        vm.ttl = ""
                
    rendered: () =>
        super()
                
    submit: () =>
        if $("form.manual").validate().form()
            @page.frozen()
            chain = new Chain
            chain.chain => (new MachineRest(@sd.host)).change_email  @vm.email,@vm.level,@vm.ttl
            chain.chain @sd.update('all')
            @hide()
            show_chain_progress(chain).done (data)=>
                @page.attach()
                (new MessageModal lang.central_email.success_add).attach()
            
class CentralChangeValueModal extends Modal
    constructor: (@sd, @page, @message) ->
        super "central-change-value-modal-", "html/central_change_value_modal.html"
        
    define_vm: (vm) =>
        vm.lang = lang.central_value
        vm.submit = @submit
        vm.normal = ""
        vm.bad = ""
        vm.message = @message
        
    rendered: () =>
        super()
                
    submit: () =>
        if $("form.manual").validate().form()
            @page.frozen()
            chain = new Chain
            chain.chain => (new MachineRest(@sd.host)).change_value @message,@vm.normal,@vm.bad
            chain.chain @sd.update('all')
            @hide()
            show_chain_progress(chain).done (data)=>
                @page.attach()
                (new MessageModal lang.central_value.success).attach()
                
class CentralHandleLogModal extends Modal
    constructor: (@sd, @page) ->
        super "central-handle-log-modal-", "html/central_handle_log_modal.html"
        
    define_vm: (vm) =>
        vm.lang = lang.central_handle_log
        vm.submit = @submit
        vm.normal = ""
        vm.bad = ""
        vm.message = @message
        vm.journal_unhandled = @subitems()
        vm.fattr_journal_status = fattr.journal_status
        vm.all_checked = false
        vm.$watch "all_checked", =>
            for v in vm.journal_unhandled
                v.checked = vm.all_checked
                
    rendered: () =>
        super()
        @vm.journal_unhandled = @subitems()
        @data_table= $("#log-table").dataTable dtable_opt(retrieve: true, bSort: false,scrollX: true)
        $(".dataTables_filter input").addClass "m-wrap small"
        $(".dataTables_length select").addClass "m-wrap small"
        $scroller = $("#journals-scroller")
        $scroller.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
            
    subitems: () =>
        try
            arrays = []
            for i in @sd.journals.items
                i.created = i.created.replace("-","/").replace("-","/").replace("T","-").replace("+08:00","")
                if !i.status
                    i.chinese_status = "未处理"
                    i.checked = false
                    arrays.push i
            arrays.reverse()
        catch error
            return []
        
    submit: () =>
        selected = ($.extend({},i.$model) for i in @vm.journal_unhandled when i.checked)
        for i in selected
            @page.frozen()
            chain = new Chain
            chain.chain => (new MachineRest(@sd.host)).handle_log i.uid
            chain.chain @sd.update('all')
            show_chain_progress(chain).done =>
        @hide()
        @page.attach()
        (new MessageModal(lang.central_handle_log.success)).attach()
                
class CentralUnmonitorModal extends Modal
    constructor: (@sd, @page) ->
        super "central-unmonitor-modal-", "html/central_unmonitor_modal.html"
        
    define_vm: (vm) =>
        vm.lang = lang.central_unmonitor
        vm.submit = @submit
        vm.device = @subitems()
        vm.fattr_monitor_status = fattr.monitor_status
        vm.all_checked = false
        vm.$watch "all_checked", =>
            for v in vm.device
                v.checked = vm.all_checked
                
    rendered: () =>
        super()
        #@vm.device = @subitems()
        @data_table= $("#unmonitor-table").dataTable dtable_opt(retrieve: true, bSort: false,scrollX: true)
        $(".dataTables_filter input").addClass "m-wrap small"
        $(".dataTables_length select").addClass "m-wrap small"
            
    subitems: () =>
        if @sd.centers.items != null
            tmp = []
            items = subitems @sd.centers.items, Uuid:"", Ip:"", Slotnr:"", Created: "",Devtype:"",Status:"",checked:false
            for i in items 
                if i.Devtype is "storage"
                    i.Chinese_devtype = "存储"
                else
                    i.Chinese_devtype = "服务器"
                tmp.push i
            tmp
             
    submit: () =>
        selected = ($.extend({},i.$model) for i in @vm.device when i.checked)
        chain = new Chain
        rest = new MachineRest @sd.host
        i = 0
        for disk in selected
            chain.chain ->
                (rest.unmonitor selected[i].Uuid).done -> i += 1
        chain.chain @sd.update("all")
        @hide()
        show_chain_progress(chain).done =>
            @page.attach()
            (new MessageModal(lang.central_unmonitor.success)).attach()
        
        
class CentralChangeEmailModal extends Modal
    constructor: (@sd, @page, @_address,@_level,@_ttl) ->
        super "central-change-email-modal-", "html/central_change_email_modal.html"
        
    define_vm: (vm) =>
        vm.lang = lang.central_email
        vm.submit = @submit
        vm.address = @_address
        vm.level = @_level
        vm.ttl = @_ttl
        
    rendered: () =>
        super()
        
    submit: () =>
        if $("form.manual").validate().form()
            @page.frozen()
            chain = new Chain
            chain.chain => (new MachineRest(@sd.host)).change_email @_address,@vm.level,@vm.ttl
            chain.chain @sd.update('all')
            @hide()
            show_chain_progress(chain).done (data)=>
                @page.attach()
                (new MessageModal lang.central_value.success_change).attach()
                


class GetcardResultModal extends Modal
    constructor: (@sd, @page, @message) ->
        super "getcard-result-modal-", "html/getcard_result_modal.html"
        
    define_vm: (vm) =>
        vm.lang = lang.central_email
        vm.submit = @submit
        vm.message = @message
        
    rendered: () =>
        super()
        
    submit: () =>
        @hide()


class RegisterChangeDataModal extends Modal
    constructor: (@sd, @page, @message) ->
        super "register-change-data-modal-", "html/register_change_data_modal.html"
        $(@sd.register).on "updated", (e, source) =>
            @init()
        
    define_vm: (vm) =>
        vm.lang = lang.register
        vm.submit = @submit

        vm.id = ""
        vm.email = ""
        vm.hotelname = ""
        vm.location=""
        vm.realname=""
        vm.tel=""
        vm.user= ""
        vm.sex = ""
        vm.options_sex = [
          { key: "请选择", value: "请选择" }
          { key: "男", value: "男" }
          { key: "女", value: "女" }
        ]
        vm.option = ""

    rendered: () =>
        super()
        @init()
        $("form.userdata").validate(
            valid_opt(
                rules:
                    tel:
                        regex: '^[0-9]*$'
                messages:
                    ip:
                        regex: "无效IP地址"))
        
        #@locations()

    init: () =>
        @vm.email = @sd.register.items["email"]
        @vm.hotelname = @sd.register.items["hotelname"]
        @vm.location = @sd.register.items["location"]
        @vm.realname = @sd.register.items["realname"]
        @vm.tel = @sd.register.items["tel"]
        @vm.id = @sd.register.items["account"]
        @vm.user = @sd.register.items["user"]

        ###if @sd.register.items["sex"] is ""
            oLanguage = "请选择"
        else
            oLanguage = @sd.register.items["sex"]###

        if @sd.register.items["sex"] is ""
            @vm.option = ""
        else
            @vm.option = @sd.register.items["sex"]

        #$("#chosen_sex option[value='"+oLanguage+"']").attr("selected","selected");  
        #$("#chosen_sex").chosen();  
         
    locations: () =>
        new PCAS('location_p', 'location_c', 'location_a', '广东省', '', '')

    submit: () =>
        if $("form.userdata").validate().form()
            #selected = $("#chosen_sex").val()
            @page.frozen()
            chain = new Chain
            chain.chain => (new MachineRest(@sd.host)).change_data @vm.user,@vm.email, @vm.hotelname, \
                                                                 @vm.location,@vm.realname,@vm.tel,@vm.id,@vm.option
            chain.chain @sd.update('all')
            @hide()
            show_chain_progress(chain).done (data)=>
                @page.attach()
                (new MessageModal lang.register.success_change).attach()

class RegisterChangePasswdModal extends Modal
    constructor: (@sd, @page, @message) ->
        super "register-change-data-modal-", "html/register_change_passwd_modal.html"
        
    define_vm: (vm) =>
        vm.lang = lang.register
        vm.submit = @submit

        vm.old_passwd = ""
        vm.new_passwd = ""
        vm.confirm_passwd = ""
        vm.account = ""
        vm.close_alert = @close_alert

    rendered: () =>
        super()
        $.validator.addMethod("same", (val, element) =>
            if @vm.new_passwd != @vm.confirm_passwd
                return false
            else
                return true
        , "两次输入的新密码不一致")

        $('.hastip').poshytip(
            className: 'tip-twitter'
            showTimeout: 0
            allowTipHover: false
            fade: false
            slide: false
            followCursor: true
        )

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

        @vm.account = @sd.register.items['account']

    submit: () =>
        if $("form.passwd").validate().form()
            @page.frozen()
            action = new SessionRest(@sd.host).change_pass @vm.account,@vm.old_passwd, @vm.new_passwd
            action.done (data) =>
                if data.status is "failed"
                    $('.alert-error', $('.passwd')).show()
                else
                    @hide()
                    (new MessageModal lang.register.success_change).attach()

    close_alert: (e) =>
        $(".alert-error").hide()

class FaceUpLoadModal extends Modal
    constructor: (@sd, @page) ->
        super "register-change-data-modal-", "html/face_upload_modal.html"
        
    define_vm: (vm) =>
        vm.lang = lang.fileupload
        vm.submit = @submit

    rendered: () =>
        super()
        $("#fileupload").fileupload(url:"http://#{@sd.host}/api/upgrade")
            .bind("fileuploaddone", (e, data) ->
                (new MessageModal(lang.fileupload.message_upgrade_success)).attach())
        $("input[name=files]").click ->
            $("tbody.files").html ""
        
    submit: () =>
        @hide()

class RegisterChangeHeadModal extends Modal
    constructor: (@sd, @page, @message) ->
        super "register-change-data-modal-", "html/register_change_head_modal.html"
        
    define_vm: (vm) =>
        vm.lang = lang.register_change_head
        vm.submit = @submit
        vm.show_old_head = true
        vm.show_div = false

    rendered: () =>
        super()
        @init(this,@page)
        #@on_load(this)
        @vm.show_old_head = true
        @vm.show_div = false

    on_load: (page) =>
        $(document).ready(`function() {
            var xhr;  
            if (window.XMLHttpRequest){  
                xhr=new XMLHttpRequest();  
            }else{  
                xhr=new ActiveXObject("Microsoft.XMLHTTP");  
            }
            var header = document.getElementById("headerss");
            var cxt= header.getContext("2d");
            var id = page.sd.register.items["account"];
            xhr.open('get','http://192.168.2.84:4567/api/downloadAvatar/' + id,true);
            xhr.send(null);
            xhr.onreadystatechange = function(){  
                if(xhr.readyState==4 || xhr.readyState==200){
                    var img = new Image();
                    img.src=xhr.responseText;
                    img.onload = function(){
                        var w = Math.min(400, img.width);
                        var h = img.height * (w / img.width);
                        header.width = w;
                        header.height = h;
                        cxt.drawImage(img,0,0);
                    }
                    console.log(xhr.responseText);  
                }  
            }
        }`)

    _upload: (base64,filename,page,thispage) =>
        $(`function() {
            try{
                function sumitImageFile(base64Codes){
                    var form=document.forms[0];
                    var formData = new FormData(form);  
                    formData.append("imageName",convertBase64UrlToBlob(base64Codes),filename);  
                    $.ajax({
                        url : "http://" + page.sd.host + "/api/upgrade",
                        type : "POST",
                        data : formData,
                        dataType:"text",
                        processData : false,        
                        contentType : false,  
                        success:function(data){
                            //window.location.href="${ctx}"+data;
                            //thispage.refresh_header();
                            random = Math.random();
                            new MessageModal(lang.fileupload.upload_success).attach();
                            return page.attach();
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

    refresh_header:() =>
        id = @sd.register.items["account"];
        urls = 'http://' + @sd.host + '/downloadAvatar/' + id + '/head/' + id + '_head.jpg';
        $("#user_img_log").attr('src', urls + "?t=" + Math.random());
        $("#headers").attr('src', urls + "?t=" + Math.random());
        #$('#user_img_log').attr('src',urls);
        #$('#headers').attr('src',urls);

    init: (page,mainpage) =>
        $(`function () {
          'use strict'
          var result = $('#result')
          var result_150 = $('#result_150')
          var result_55 = $('#result_55')
          var exifNode = $('#exif')
          var thumbNode = $('#thumbnail')
          var actionsNode = $('#actions')
          var imgs = $('#img_preview')
          var currentFile
          var coordinates
          var upload_button = false;
          var jcrop_api,
            boundx,
            boundy,
            $preview = $('#preview-pane'),
            $pcnt = $('#preview-pane .preview-container'),
            $pimg = $('#preview-pane .preview-container img'),
            xsize = $pcnt.width(),
            ysize = $pcnt.height();
         
          function displayExifData (exif) {
            var thumbnail = exif.get('Thumbnail')
            var tags = exif.getAll()
            var table = exifNode.find('table').empty()
            var row = $('<tr></tr>')
            var cell = $('<td></td>')
            var prop
            if (thumbnail) {
              thumbNode.empty()
              loadImage(thumbnail, function (img) {
                thumbNode.append(img).show()
              }, {orientation: exif.get('Orientation')})
            }
            for (prop in tags) {
              if (tags.hasOwnProperty(prop)) {
                table.append(
                  row.clone()
                    .append(cell.clone().text(prop))
                    .append(cell.clone().text(tags[prop]))
                )
              }
            }
            exifNode.show()
          }

          function updateResults (img, data) {
            var content
            if (!(img.src || img instanceof HTMLCanvasElement)) {
              content = $('<span>Loading image file failed</span>')
            } else {
              page.vm.show_div = true;
              content = $('<a target="_blank">').append(img)
                .attr('download', currentFile.name)
                .attr('href', img.src || img.toDataURL())
            }
            result.children().replaceWith(content)
            if (img.getContext) {
              //actionsNode.show()
            }
            if (data && data.exif) {
              displayExifData(data.exif)
            }
            var imgNode = result.find('img, canvas');
            imgs.src = img.src;
            if (upload_button == false){
                /*
                imgNode.Jcrop({
                    bgOpacity: 0.5,
                    bgColor: '#e2e2e2',
                    addClass: 'jcrop-light',
                    setSelect: [
                      40,
                      40,
                      150,
                      150
                    ],
                    onChange: updatePreview,
                    onSelect: updatePreview,
                    aspectRatio: xsize / ysize
                },function(){
                  var bounds = this.getBounds();
                  boundx = bounds[0];
                  boundy = bounds[1];
                  jcrop_api = this;
                  $preview.appendTo(jcrop_api.ui.holder);
                });
                */
                imgNode.Jcrop({
                    bgOpacity: 0.5,
                    bgColor: '#e2e2e2',
                    addClass: 'jcrop-light',
                    setSelect: [
                      40,
                      40,
                      150,
                      150
                    ],
                    onSelect: function (coords) {
                      coordinates = coords
                    },
                    aspectRatio: 1,//正方形裁剪框
                    onRelease: function () {
                      coordinates = null
                    }
                })
            }
          }
          function updatePreview(c)
            {
              if (parseInt(c.w) > 0)
              {
                var rx = xsize / c.w;
                var ry = ysize / c.h;

                $pimg.css({
                  width: Math.round(rx * boundx) + 'px',
                  height: Math.round(ry * boundy) + 'px',
                  marginLeft: '-' + Math.round(rx * c.x) + 'px',
                  marginTop: '-' + Math.round(ry * c.y) + 'px'
                });
              }
            };
          function displayImage (file, options) {
            currentFile = file
            if (!loadImage(
                file,
                updateResults,
                options
              )) {
              result.children().replaceWith(
                $('<span>' +
                  'Your browser does not support the URL or FileReader API.' +
                  '</span>')
              )
            }
          }

          function dropChangeHandler (e) {
            e.preventDefault()
            e = e.originalEvent
            var target = e.dataTransfer || e.target
            var file = target && target.files && target.files[0]
            var options = {
              maxWidth: 400,
              maxHeight: 300,
              canvas: true,
              pixelRatio: window.devicePixelRatio,
              downsamplingRatio: 0.5,
              orientation: true
            }
            if (!file) {
              page.vm.show_old_head = true;
              return
            }
            exifNode.hide()
            thumbNode.hide()
            displayImage(file, options)
          }

          // Hide URL/FileReader API requirement message in capable browsers:
          if (window.createObjectURL || window.URL || window.webkitURL ||
            window.FileReader) {
            page.vm.show_div = false;
            /*
            var xhr;
            var imgNodes = result.find('img, canvas')[0];
            if (window.XMLHttpRequest){  
                xhr=new XMLHttpRequest();  
            }else{  
                xhr=new ActiveXObject("Microsoft.XMLHTTP");  
            }
            var id = page.sd.register.items["account"];
            xhr.open('get','http://192.168.2.84:4567/api/downloadAvatar/' + id,true);
            xhr.send(null);
            xhr.onreadystatechange = function(){
                if(xhr.readyState==4 || xhr.readyState==200){
                    //var header = document.getElementById("headerss");
                    var cxt= imgNodes.getContext("2d");
                    var img = new Image();
                    img.src=xhr.responseText;
                    img.onload = function(){
                        var w = Math.min(400, img.width);
                        var h = img.height * (w / img.width);
                        header.width = w;
                        header.height = h;
                        cxt.drawImage(img,0,0);
                    }
                    //result.append(img).show();
                    console.log(xhr.responseText);  
                }  
            }*/
            //result.children().hide()
          }

          $(document)
            .on('dragover', function (e) {
              e.preventDefault()
              e = e.originalEvent
              e.dataTransfer.dropEffect = 'copy'
            })
            .on('drop', dropChangeHandler)

          $('#file-input')
            .on('change', function (e) {   
                dropChangeHandler(e)
                page.vm.show_old_head = false
            })

          $('#edit')
            .on('click', function (event) {
              event.preventDefault()
              var imgNode = result.find('img, canvas')
              var img = imgNode[0]
              var pixelRatio = window.devicePixelRatio || 1
              imgNode.Jcrop({
                bgOpacity: 0.5,
                bgColor: '#e2e2e2',
                addClass: 'jcrop-light',
                setSelect: [
                  40,
                  40,
                  (img.width / pixelRatio) - 40,
                  (img.height / pixelRatio) - 40
                ],
                onSelect: function (coords) {
                  coordinates = coords
                },
                aspectRatio: 1,//正方形裁剪框
                onRelease: function () {
                  coordinates = null
                }
              }).parent().on('click', function (event) {
                event.preventDefault()
              })
            })

          $('#crop')
            .on('click', function (event) {
              event.preventDefault()
              upload_button = true;
              var img = result.find('img, canvas')[0]
              var pixelRatio = window.devicePixelRatio || 1
              if (img && coordinates) {
                updateResults(loadImage.scale(img, {
                  left: coordinates.x * pixelRatio,
                  top: coordinates.y * pixelRatio,
                  sourceWidth: coordinates.w * pixelRatio,
                  sourceHeight: coordinates.h * pixelRatio,
                  minWidth: result.width(),
                  maxWidth: result.width(),
                  pixelRatio: pixelRatio,
                  downsamplingRatio: 0.5
                }))
                coordinates = null
              }
            })

          $('#submit')
            .on('click', function (event) {
                var img = result.find('img, canvas')[0];
                var pixelRatio = window.devicePixelRatio || 1
                if ( coordinates ) {
                    updateResults(loadImage.scale(img, {
                        left: coordinates.x * pixelRatio,
                        top: coordinates.y * pixelRatio,
                        sourceWidth: coordinates.w * pixelRatio,
                        sourceHeight: coordinates.h * pixelRatio,
                        minWidth: result.width(),
                        maxWidth: result.width(),
                        pixelRatio: pixelRatio,
                        downsamplingRatio: 0.5
                    }))
                    var img2 = result.find('img, canvas')[0];
                    var urls = img2.toDataURL();
                    var filename = (page.sd.register.items["account"]).toString() + "_head.jpg";
                    page.hide();
                    page._upload(urls,filename,mainpage,page);
                }else{
                    $('.alert-error').show();
                }
            })
        }`)

    submit: () =>
        return

class RegisterChangeHeaderModal extends Modal
    constructor: (@sd, @page, @message) ->
        super "register-change-data-modal-", "html/register_change_header_modal.html"
        
    define_vm: (vm) =>
        vm.lang = lang.register_change_head
        vm.submit = @submit
        vm.loadImageFile = @loadImageFile
        vm.show_head = false
        vm.show_canvas = false

    rendered: () =>
        super()
        @init(this,@page)
        @vm.show_head = false
        @vm.show_canvas = false

    _upload: (base64,filename,page) =>
        $(`function() {
            try{
                function sumitImageFile(base64Codes){
                    var form=document.forms[0];
                    var formData = new FormData(form);  
                    formData.append("imageName",convertBase64UrlToBlob(base64Codes),filename);  
                    $.ajax({
                        url : "http://" + page.sd.host + "/api/upgrade",
                        type : "POST",
                        data : formData,
                        dataType:"text",
                        processData : false,        
                        contentType : false,  
                        success:function(data){
                            //window.location.href="${ctx}"+data;
                            new MessageModal(lang.fileupload.upload_success).attach();
                            return page.attach();
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

    init: (page,mainpage) =>
        $(`function(){
            $("#file_upload").change(function () {
                var $file = $(this);
                var fileObj = $file[0];
                var windowURL = window.URL || window.webkitURL;
                var dataURL;
                var $img0 = $("#preview0");
                var $img1 = $("#preview1");
                var $img2 = $("#preview2");
                var $img3 = $("#preview3");
                var jcropApi;

                if (fileObj && fileObj.files && fileObj.files[0]) {

                    dataURL = windowURL.createObjectURL(fileObj.files[0]);
                    page.vm.show_head = true;
                    $img0.attr('src', dataURL);
                    $img1.attr('src', dataURL);
                    $img2.attr('src', dataURL);
                    $img3.attr('src', dataURL);

                    //真实尺寸
                    var img = new Image;    
                    img.onload = function(){ 
                        cutImage($(".jcrop_w>img"),img.width,img.height);

                        //默认图像位置
                        function cutImage(obj,ow,oh) {
                            var w = 394,
                                h = 340,
                                //iw = obj.width(),
                                //ih = obj.height();
                                iw = ow,
                                ih = oh;
                            console.log(iw);
                            console.log(ih);

                            if(iw > w || ih > h){
                                if(iw / ih > w / h){
                                    obj.css({
                                        width: w,
                                        height: w * ih / iw,
                                        top: (h - (w * ih / iw)) / 2,
                                        left: 0
                                    });
                                    init_jcrop("a",img.height,img.width);
                                }else{
                                    obj.css({
                                        height: h,
                                        width: h * iw / ih,
                                        top: 0,
                                        left: (w - (h * iw / ih)) / 2
                                    });
                                    init_jcrop("b",img.height,img.width);
                                }
                            }else{
                                obj.css({
                                    left: (w - iw) / 2,
                                    top: (h - ih ) / 2,
                                    height: ih,
                                    width: iw
                                });
                                init_jcrop("c",img.height,img.width);
                            }
                        }
                    };    
                    img.src = dataURL;
                } else {
                    dataURL = $file.val();
                    var imgObj = document.getElementById("preview1");
                    //imgObj.style.filter = "progid:DXImageTransform.Microsoft.AlphaImageLoader(sizingMethod=scale)";
                    //imgObj.filters.item("DXImageTransform.Microsoft.AlphaImageLoader").src = dataURL;
                }

                function init_jcrop(mode,nature_h,nature_w){
                    var jcropApi;
                    if (mode == "c"){
                        var _Jw = (($("#target").width()/2) - nature_w/6 ),
                            _Jh = (($("#target").height()/2) - nature_h/6),
                            _Jw2 = _Jw + (nature_w/3),
                            _Jh2 = _Jh + (nature_h/3);
                    }else{
                        var _Jw = ($("#target").width() - 110) / 2 ,
                            _Jh = ($("#target").height() - 135) / 2 ,
                            _Jw2 = _Jw + 110,
                            _Jh2 = _Jh + 135;
                    }
    
                    $('#target').Jcrop({
                        setSelect: [_Jw, _Jh, _Jw2, _Jh2],
                        onChange: showPreview,
                        onSelect: showPreview,
                        bgFade: true,
                        addClass : 'jcrop-light',
                        bgColor: "rgb(241, 240, 240)",
                        allowSelect:false, //不允许选新框
                        //aspectRatio: 110/135,
                        aspectRatio: 1,//正方形裁剪框
                        bgOpacity: .5
                    }, function() {
                        jcropApi = this;
                        jcropApi.ui.selection.addClass('jcrop-selection');
                    });

                    $("#idLeft").click(function(e){
                        imgRotate(-90);
                        return false;
                    });
                    $("#idRight").click(function(e){
                        imgRotate(90);
                        return false;
                    });
                    $("#idBig").click(function(e){
                        imgToSize(20);
                        return false;
                    });
                    $("#idSmall").click(function(e){
                        imgToSize(-20);
                        return false;
                    });

                    //图片旋转
                    function imgRotate(deg){
                        var img1 = $(".jcrop_w>img"),
                            _data = parseInt($(".jc-demo-box").attr("data"));
                        console.log(_data);
                        if($.browser.version == 8.0 || $.browser.version == 7.0 || $.browser.version == 6.0 ){
                            var sin = Math.sin(Math.PI / 180 * (_data + deg)), cos = Math.cos(Math.PI / 180 * (_data + deg));
                            var _filter = "progid:DXImageTransform.Microsoft.Matrix(M11=" + cos + "," +  "M12=" + (-sin)
                                + ",M21=" + sin+ ",M22=" + cos + ",SizingMethod='auto expand')";
                            img1.css({
                                filter: _filter
                            });
                            $('.pre-1 img,.pre-2 img,.pre-3 img').css({
                                filter: _filter
                            });

                        }else{
                            var _deg = deg + _data;
                            var _val =  "rotate("+ _deg + "deg)";
                            img1.css({
                                "-webkit-transform": _val,
                                   "-moz-transform": _val,
                                    "-ms-transform": _val,
                                     "-o-transform": _val,
                                        "transform": _val
                            });
                            $('.pre-1 img,.pre-2 img,.pre-3 img').css({
                                "-webkit-transform": _val,
                                   "-moz-transform": _val,
                                    "-ms-transform": _val,
                                     "-o-transform": _val,
                                        "transform": _val
                            });
                        }

                        var     fiw = $('.jcrop_w>img').width(),
                                fih = $('.jcrop_w>img').height(),
                                ow = Math.floor((395 - fiw) / 2),
                                oh = Math.floor((340 - fih) / 2),
                                cx = $("#small").position().left,
                                cy = $("#small").position().top,
                                rx = 110 / $("#small").width(),
                                ry = 135 / $("#small").height(),
                                rx1 = 73 / $("#small").width(),
                                ry1 = 90 / $("#small").height(),
                                rx2 = 40 / $("#small").width(),
                                ry2 = 48 / $("#small").height();

                        if($.browser.version == 8.0 || $.browser.version == 7.0 || $.browser.version == 6.0){
                            pre_img2($('.pre-1 img'), rx, fih, ry, fiw, cx, cy, ow, oh);
                            pre_img2($('.pre-2 img'), rx1, fih, ry1, fiw, cx, cy, ow, oh);
                            pre_img2($('.pre-3 img'), rx2,  fih, ry2, fiw, cx, cy, ow, oh);
                        }else{
                            pre_img2($('.pre-1 img'), rx, fiw, ry, fih, cx, cy, ow, oh);
                            pre_img2($('.pre-2 img'), rx1, fiw, ry1, fih, cx, cy, ow, oh);
                            pre_img2($('.pre-3 img'), rx2, fiw, ry2, fih, cx, cy, ow, oh);
                        }

                        $(".jcrop_w img").css({
                            left: ow,
                            top: oh
                        });

                        if( deg > 0){
                            if(_data == 270){
                                _data = 0;
                            }else{
                                _data = _data + 90;
                            }
                        }else{
                            if(_data == 0){
                                _data = 270;
                            }else{
                                _data = _data - 90;
                            }
                        }
                        $("#d").val(_data);
                        $(".jc-demo-box").attr("data", _data);
                    }

                    //放大缩小图片
                    function imgToSize(size) {
                        var iw = $('.jcrop_w>img').width(),
                            ih = $('.jcrop_w>img').height(),
                            _data = $(".jc-demo-box").attr("data"),
                            _w = Math.round(iw + size),
                            _h = Math.round(((iw + size) * ih) / iw);

                        if(($.browser.version == 8.0 || $.browser.version == 7.0 || $.browser.version == 6.0) && (_data == 90 || _data == 270)){
                            $('.jcrop_w>img').width(_h).height(_w);
                        }else{
                            $('.jcrop_w>img').width(_w).height(_h);
                        }

                        var fiw = $('.jcrop_w>img').width(),
                            fih = $('.jcrop_w>img').height(),
                            ow = (395 - fiw) / 2,
                            oh = (340 - fih) / 2,
                            cx = $("#small").position().left,
                            cy = $("#small").position().top,
                            rx = 110 / $("#small").width(),
                            ry = 135 / $("#small").height(),
                            rx1 = 73 / $("#small").width(),
                            ry1 = 90 / $("#small").height(),
                            rx2 = 40 / $("#small").width(),
                            ry2 = 48 / $("#small").height();

                        if(($.browser.version == 8.0 || $.browser.version == 7.0 || $.browser.version == 6.0) && (_data == 90 || _data == 270)){
                            pre_img2($('.pre-1 img'), rx, fih, ry, fiw, cx, cy, ow, oh);
                            pre_img2($('.pre-2 img'), rx1, fih, ry1, fiw, cx, cy, ow, oh);
                            pre_img2($('.pre-3 img'), rx2, fih, ry2, fiw, cx, cy, ow, oh);
                        }else{
                            pre_img2($('.pre-1 img'), rx, fiw, ry, fih, cx, cy, ow, oh);
                            pre_img2($('.pre-2 img'), rx1, fiw, ry1, fih, cx, cy, ow, oh);
                            pre_img2($('.pre-3 img'), rx2,  fiw, ry2, fih, cx, cy, ow, oh);
                        }
                        $(".jcrop_w img").css({
                            left: ow,
                            top: oh
                        });

                    };
                    function pre_img2(obj, rx, iw, ry, ih, cx, cy, ow, oh){
                        obj.css({
                            width: Math.round(rx * iw) + 'px',
                            height: Math.round(ry * ih) + 'px'
                        });
                        if( cy >= oh && cx >= ow){
                            obj.css({
                                marginLeft: '-' + Math.round(rx * (cx - ow)) + 'px',
                                marginTop: '-' + Math.round(ry * (cy - oh)) + 'px'
                            });
                        }else if( cy <= oh && cx >= ow){
                            obj.css({
                                marginLeft: "-" + Math.round(rx * (cx - ow)) + 'px',
                                marginTop: Math.round(ry * (oh - cy)) + 'px'
                            });
                        }else if( cy >= oh && cx <= ow){
                            obj.css({
                                marginLeft: Math.round(rx * (ow - cx)) + 'px',
                                marginTop: '-' + Math.round(ry * (cy - oh)) + 'px'
                            });
                        }else if( cy <= oh && cx <= ow){
                            obj.css({
                                marginLeft: Math.round(rx * (ow - cx)) + 'px',
                                marginTop: Math.round(ry * (oh - cy)) + 'px'
                            });
                        }
                    };

                    function showPreview(c){
                        global_api = c;
                        var iw = $('.jcrop_w>img').width(),
                            ih = $('.jcrop_w>img').height(),
                            ow = (394 - iw) / 2,
                            oh = (340 - ih) / 2,
                            rx = 135 / c.w,
                            ry = 135 / c.h,
                            rx1 = 90 / c.w,
                            ry1 = 90 / c.h,
                            rx2 = 48 / c.w,
                            ry2 = 48 / c.h,
                            _data = $(".jc-demo-box").attr("data");

                        if(($.browser.version == 8.0 || $.browser.version == 7.0 || $.browser.version == 6.0) && (_data == 90 || _data == 270)){
                            pre_img2($('.pre-1 img'), rx, ih, ry, iw, c.x, c.y, ow, oh);
                            pre_img2($('.pre-2 img'), rx1, ih, ry1, iw, c.x, c.y, ow, oh);
                            pre_img2($('.pre-3 img'), rx2, ih, ry2, iw, c.x, c.y, ow, oh);
                        }else{
                            pre_img2($('.pre-1 img'), rx, iw, ry, ih, c.x, c.y, ow, oh);
                            pre_img2($('.pre-2 img'), rx1, iw, ry1, ih, c.x, c.y, ow, oh);
                            pre_img2($('.pre-3 img'), rx2, iw, ry2, ih, c.x, c.y, ow, oh);
                        }
                        $('#x').val(c.x);
                        $('#y').val(c.y);
                        $('#w').val(c.w);
                        $('#h').val(c.h);

                        var img=document.getElementById("preview1");  
                        var ctx=document.getElementById("head_canvas").getContext("2d");  
                        var bod_w = nature_w/iw; //缩放比例
                        var bod_h = nature_h/ih; //缩放比例 
                        if (mode == "b"){
                            ctx.drawImage(img,(c.x-($("#target").width()-iw)/2)*bod_w,c.y*bod_h, c.w*bod_w, c.h*bod_h,0,0,140,140);
                        }else if (mode == "a"){
                            ctx.drawImage(img,c.x*bod_w,(c.y-($("#target").height()-ih)/2)*bod_h, c.w*bod_w, c.h*bod_h,0,0,140,140);
                        }else{
                            ctx.drawImage(img,c.x-($("#target").width()-iw)/2,c.y-($("#target").height()-ih)/2, c.w, c.h,0,0,140,140);
                        }
                        if (c.x-($("#target").width()-iw)/2 <= 0){
                            jcropApi.setOptions({
                                allowMove: false
                            })
                        }else{
                            jcropApi.setOptions({
                                allowMove: true
                            })
                        }
                    }
                } 
            });

            $('#submit').on('click', function (event) {
                var _base64 = document.getElementById("head_canvas").toDataURL();
                console.log(_base64);
                var filename = (page.sd.register.items["account"]).toString() + "_head.jpg";
                page.hide();
                page._upload(_base64,filename,mainpage);
            })
        }`)

    submit: () =>
        return

class RegisterRechargeModal extends Modal
    constructor: (@sd, @page) ->
        super "register-recharge-modal-", "html/register_recharge_modal.html"
        
    define_vm: (vm) =>
        vm.lang = lang.register_recharge
        vm.submit = @submit
        vm.option = "wechat"
        vm.compare_result = ""
        vm.pay_result = ""

    rendered: () =>
        super()
        @vm.pay_result = ""
        @initpage(this)

    submit: () =>
        @hide()

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
                    
                    if (current == 2){
                        var codes = document.getElementById("code");
                        if(page.vm.option == "wechat"){
                            codes.src = "images/wechat_code.png";
                            page.vm.pay_result = "打开微信,扫描以下二维码,向我支付";
                        }else if (page.vm.option == "alipay"){
                            codes.src = "images/alipay_code.png";
                            page.vm.pay_result = "打开支付宝,扫描以下二维码,向我支付";
                        }else{
                            return false;
                            codes.src = "images/credit_code.jpg";
                            page.vm.pay_result = "打开微信,扫描以下二维码,向我支付";
                        }
                    }else{
                        return false;
                        /*
                        if (page.vm.show_canvas == false){
                            $('.alert-error', $('#submit_form')).show();
                            return false;
                        }else{
                            page.compare();
                            $('.alert-error', $('#submit_form')).hide();
                        }
                        */
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
                        page.vm.next_action = "读卡"
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
            $('#form_wizard_1').find('.button-previous').hide();
            $('#form_wizard_1 .button-submit').click(function () {
                page.attach();
            }).hide();
        }`)

class RegisterRecordModal extends Modal
    constructor: (@sd, @page, @uid ) ->
        super "register-recharge-modal-", "html/register_record_modal.html"
        
    define_vm: (vm) =>
        vm.lang = lang.register_record
        vm.submit = @submit
        vm.option = "wechat"
        vm.compare_result = ""
        vm.pay_result = ""

        vm.personName = ""
        vm.sex = ""
        vm.birthday = ""
        vm.nation = ""
        vm.personId = ""
        vm.address = ""
        vm.startDate = ""
        vm.endDate = ""
        vm.department = ""

    rendered: () =>
        super()
        #new WOW().init();
        @vm.pay_result = ""
        @person(this,@uid)
        @own(this,@uid)
        $("#myTab li:eq(0) a").tab "show"
        @person_data(this,@uid)

    submit: () =>
        @hide()

    person_data:(page,uid) =>
        $(`function() {
            var xhr;  
            if (window.XMLHttpRequest){  
                xhr=new XMLHttpRequest();  
            }else{  
                xhr=new ActiveXObject("Microsoft.XMLHTTP");  
            }
            xhr.open('get','http://' + page.sd.host + '/api/getCMsg/' + uid,true);
            xhr.send(null);
            xhr.onreadystatechange = function(){  
                if(xhr.readyState==4 || xhr.readyState==200){
                    if (xhr.responseText == "null"){
                        return (new MessageModal(lang.register_record.no_data)).attach();
                    }else{
                        var _data = JSON.parse(xhr.responseText);
                        page.vm.personName = _data.personName;
                        page.vm.sex = _data.sex;
                        page.vm.birthday = _data.birthday;
                        page.vm.nation = _data.nation;
                        page.vm.personId = _data.personId;
                        page.vm.address = _data.address;
                        page.vm.startDate = _data.startDate;
                        page.vm.endDate = _data.endDate;
                        page.vm.department = _data.department;
                    }
                }  
            }
        }`)

    person: (page,uid) =>
        $(document).ready(`function() {
            var xhr;  
            if (window.XMLHttpRequest){  
                xhr=new XMLHttpRequest();  
            }else{  
                xhr=new ActiveXObject("Microsoft.XMLHTTP");  
            }
            var header = document.getElementById("person");
            var cxt= header.getContext("2d");
            xhr.open('get','http://' + page.sd.host + '/api/getComparePic/' + uid + '/person' ,true);
            xhr.send(null);
            xhr.onreadystatechange = function(){  
                if(xhr.readyState==4 || xhr.readyState==200){
                    var img = new Image();
                    img.src=xhr.responseText;
                    img.onload = function(){
                        var w = Math.min(400, img.width);
                        var h = img.height * (w / img.width);
                        header.width = w;
                        header.height = h;
                        cxt.drawImage(img,0,0);
                    }
                    console.log(xhr.responseText);  
                }  
            }
        }`)

    own: (page,uid) =>
        $(document).ready(`function() {
            var xhr;  
            if (window.XMLHttpRequest){  
                xhr=new XMLHttpRequest();  
            }else{  
                xhr=new ActiveXObject("Microsoft.XMLHTTP");  
            }
            var header = document.getElementById("own");
            var cxt= header.getContext("2d");
            xhr.open('get','http://' + page.sd.host + '/api/getComparePic/' + uid + '/own' ,true);
            xhr.send(null);
            xhr.onreadystatechange = function(){  
                if(xhr.readyState==4 || xhr.readyState==200){
                    var img = new Image();
                    img.src=xhr.responseText;
                    img.onload = function(){
                        var w = Math.min(1000, img.width);
                        var h = img.height * (w / img.width);
                        header.width = w;
                        header.height = h;
                        cxt.drawImage(img,0,0);
                    }
                    //console.log(xhr.responseText);  
                }  
            }
        }`)

class RegisterDetailModal extends Modal
    constructor: (@sd, @page, @uid ) ->
        super "register-recharge-modal-", "html/register_detail_modal.html"
        
    define_vm: (vm) =>
        vm.lang = lang.register_record
        vm.submit = @submit

        vm.account = ""
        vm.user = ""
        vm.realname = ""
        vm.created = ""
        vm.sex = ""
        vm.tel = ""
        vm.email = ""
        vm.userlevel = ""
        vm.average = ""
        vm.recharge = ""
        vm.remain = ""
        vm.total = ""
        vm.location = ""
        vm.hotelname = ""

    rendered: () =>
        super()
        $("#myTab li:eq(0) a").tab "show"
        @on_load(this)
        @person_data(this,@uid)
        
    submit: () =>
        @hide()

    person_data:(page,uid) =>
        $(`function() {
            var xhr;  
            if (window.XMLHttpRequest){  
                xhr=new XMLHttpRequest();  
            }else{  
                xhr=new ActiveXObject("Microsoft.XMLHTTP");  
            }
            xhr.open('get','http://' + page.sd.host + '/api/getUMsg/' + uid,true);
            xhr.send(null);
            xhr.onreadystatechange = function(){  
                if(xhr.readyState==4 || xhr.readyState==200){
                    if (xhr.responseText == "null"){
                        return (new MessageModal(lang.register_record.no_data)).attach();
                    }else{
                        var _data = JSON.parse(xhr.responseText);
                        page.vm.account = _data.detail.account;
                        page.vm.user = _data.detail.user;
                        page.vm.realname = _data.detail.realname;
                        page.vm.created =_data.detail.created;
                        page.vm.sex = _data.detail.sex;
                        page.vm.tel = _data.detail.tel;
                        page.vm.email = _data.detail.email;
                        page.vm.userlevel =_data.detail.userlevel;
                        page.vm.average = _data.detail.average;
                        page.vm.recharge = _data.detail.recharge;
                        page.vm.remain = _data.detail.remain;
                        page.vm.total = _data.detail.total;
                        page.vm.location = _data.detail.location;
                        page.vm.hotelname = _data.detail.hotelname;

                        if (page.vm.hotelname == ""){
                            page.vm.hotelname = "未填写";
                        }
                        if (page.vm.location == ""){
                            page.vm.location = "未填写";
                        }
                        if (page.vm.realname == ""){
                            page.vm.realname = "未填写";
                        }
                        if (page.vm.tel == ""){
                            page.vm.tel = "未填写";
                        }
                        if (page.vm.sex == ""){
                            page.vm.sex = "未填写";
                        }
                        if (page.vm.user == ""){
                            page.vm.user = "未填写";
                        }
                    }
                }  
            }
        }`)

    on_load: (page) =>
        $(document).ready(`function() {
            try{
                var xhr;  
                if (window.XMLHttpRequest){  
                    xhr=new XMLHttpRequest();  
                }else{  
                    xhr=new ActiveXObject("Microsoft.XMLHTTP");  
                }
                var header = document.getElementById("person");
                var cxt= header.getContext("2d");
                xhr.open('get','http://' + page.sd.host + '/api/downloadAvatar/' + page.uid ,true);
                xhr.send(null);
                xhr.onreadystatechange = function(){  
                    if(xhr.readyState==4 || xhr.readyState==200){
                        var img = new Image();
                        img.src=xhr.responseText;
                        img.onload = function(){
                            var w = Math.min(400, img.width);
                            var h = img.height * (w / img.width);
                            header.width = w;
                            header.height = h;
                            cxt.drawImage(img,0,0);
                        }  
                    }  
                }
            }catch(e){
                console.log('error');
            }
        }`)


class RegisterAddModal extends Modal
    constructor: (@sd, @page) ->
        super "register-recharge-modal-", "html/register_add_modal.html"
        
    define_vm: (vm) =>
        vm.lang = lang.register_record
        vm.submit = @submit

        vm.register_email = ""
        vm.register_name = ""
        vm.register_passwd = ""
        vm.register_confirm_passwd= ""
        vm.register_hotelname = ""
        vm.user_id = ""
        vm.forget_email = ""

    rendered: () =>
        super()
        new PCAS('location_p', 'location_c', 'location_a', '广东省', '', '')
        @init(this,@page)

    submit: () =>
        if $("form.register-form").validate().form()
            selected_p = $("#location_p").val();
            selected_c = $("#location_c").val();
            selected_a = $("#location_a").val();

            if selected_a is "市辖区"
                return (new MessageModal(@vm.lang.location_a_error)).attach();
            else
                query = new SessionRest(@sd.host);
                machine_detail = query.register(@vm.register_name,@vm.register_passwd,@vm.register_email,selected_p + selected_c + selected_a + @vm.register_hotelname);
                machine_detail.done (data) =>
                    if data.status is "success"
                        (new MessageModal(lang.centrallogin.register_success)).attach();
                        @hide();
                        @page.attach();
                    else
                        (new MessageModal(lang.centrallogin.email_error)).attach();
                
                machine_detail.fail ->
                    (new MessageModal(page.lang.centrallogin.link_error)).attach();

    init: (page,mainpage) =>
        $(`function() {
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
                        query = new SessionRest(page.sd.host);
                        machine_detail = query.register(page.vm.register_name,page.vm.register_passwd,page.vm.register_email,selected_p + selected_c + selected_a + page.vm.register_hotelname);
                        machine_detail.done(function(data) {
                          if (data.status === "success") {
                            return (new MessageModal(lang.centrallogin.register_success)).attach();
                          } else {
                            return (new MessageModal(lang.centrallogin.email_error)).attach();
                            }
                        });
                        page.hide();
                        mainpage.attach();
                        return machine_detail.fail(function() {
                          return (new MessageModal(page.lang.centrallogin.link_error)).attach();
                        });
                    }
                }
            });
        }`)


class FaceQuickChangeCam extends Modal
    constructor: (@sd, @page, @selected) ->
        super "central-server-modal-", "html/face_change_cam_modal.html"
        @mode = @selected
        
    define_vm: (vm) =>
        @_cam = new CameraManager
        vm.lang = lang.central_modal
        vm.submit = @submit
        #vm.ip = "rtsp://admin:12345@192.168.2.124:554/Streaming/Channels/1"
        vm.username = "admin"
        vm.passwd = "12345"
        vm.ip = "192.168.2.124"
        vm.port = "554"
        vm.mode = @mode
        vm.options_cam = [
          { key: "usb摄像头", value: "usb" }
          { key: "ip摄像头", value: "ip" }
        ]
        vm.show_url = false
        
    rendered: () =>
        super()
        @init()
        $("#cam_option").change =>
            selected = $("#cam_option").val()
            if selected is "ip"
                @vm.show_url = true
            else
                @vm.show_url = false
        ###$("form.create").validate(
            valid_opt(
                rules:
                    ip:
                        required: true
                        regex: /\d{1,3}(\.\d{1,3})$/
                        same:true
                    machinetype:
                        required: true
                messages:
                    ip:
                        required: "请输入ip地址"
                    machinetype:
                        required: "请选择类型"))###
    init:() =>
        $("#cam_option option[value='" + @selected + "']").attr("selected","selected");  
        $("#cam_option").chosen();
        if @selected is "ip"
           @vm.show_url = true

    change_cam:() =>
        selected = $("#cam_option").val()
        @mode = selected
        if @mode is "ip"
            @vm.show_ip_cam = true
            @ip_camera(this);
        else
            @vm.show_ip_cam = false

    connect_cam:() =>
        url = 'rtsp://' + @vm.username  + ':' + @vm.passwd + '@' + @vm.ip + ':' + @vm.port + '/vedio.mp4'
        console.log(url)
        @_cam.connect_ipcam(url)
  

    submit: () =>
        selected = $("#cam_option").val()
        @page.frozen()
        #@connect_cam()
        @page.change_cam(selected)
        @hide()
                
this.FaceQuickChangeCam = FaceQuickChangeCam
this.RegisterAddModal = RegisterAddModal
this.RegisterDetailModal = RegisterDetailModal
this.RegisterChangePasswdModal = RegisterChangePasswdModal
this.RegisterRecordModal = RegisterRecordModal
this.RegisterRechargeModal = RegisterRechargeModal
this.GetcardResultModal = GetcardResultModal
this.RegisterChangeDataModal = RegisterChangeDataModal
this.RegisterChangeHeadModal = RegisterChangeHeadModal
this.RegisterChangeHeaderModal = RegisterChangeHeaderModal
this.FaceUpLoadModal = FaceUpLoadModal

################################################################
this.CentralChangeEmailModal = CentralChangeEmailModal
this.CentralUnmonitorModal = CentralUnmonitorModal
this.CentralHandleLogModal = CentralHandleLogModal
this.CentralEmailDeleteModal = CentralEmailDeleteModal
this.CentralAddEmailModal = CentralAddEmailModal
this.CentralChangeValueModal = CentralChangeValueModal
this.CentralDownloadLogModal = CentralDownloadLogModal
this.CentralManualModal = CentralManualModal
this.CentralCreateServerModal = CentralCreateServerModal
this.CentralCreateStoreModal = CentralCreateStoreModal
this.CentralCreateClientModal = CentralCreateClientModal
this.CentralStartModal = CentralStartModal
this.CentralExpandModal = CentralExpandModal
this.CentralSearchModal = CentralSearchModal
this.CentralServerCpuModal = CentralServerCpuModal
this.CentralServerCacheModal = CentralServerCacheModal
this.CentralServerMemModal = CentralServerMemModal
this.CentralStoreDetailModal = CentralStoreDetailModal
this.CentralRecordDeleteModal = CentralRecordDeleteModal
this.CentralPieModal = CentralPieModal

###############################################################
this.ConfirmModal = ConfirmModal
this.ConfirmModal_more = ConfirmModal_more
this.ConfirmModal_link = ConfirmModal_link
this.ConfirmModal_unlink = ConfirmModal_unlink
this.ConfirmModal_scan = ConfirmModal_scan
this.EthBondingModal = EthBondingModal
this.InitrCreateModal = InitrCreateModal
this.InitrDeleteModal = InitrDeleteModal
this.MessageModal = MessageModal
this.MessageModal_reboot = MessageModal_reboot
this.Modal = Modal
this.RaidCreateDSUUI = RaidCreateDSUUI
this.RaidSetDiskRoleModal = RaidSetDiskRoleModal
this.RaidCreateModal = RaidCreateModal
this.RaidDeleteModal = RaidDeleteModal
this.ResDeleteModal = ResDeleteModal
this.ServerUI = ServerUI
this.SyncDeleteModal = SyncDeleteModal
this.VolumeCreateModal = VolumeCreateModal
this.VolumeDeleteModal = VolumeDeleteModal
this.VolumeMapModal = VolumeMapModal
this.VolumeUnmapModal = VolumeUnmapModal
this.FsCreateModal = FsCreateModal
this.FsChooseModal = FsChooseModal