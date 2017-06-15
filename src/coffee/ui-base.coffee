dtable_opt = (opt) ->
    global =
        aLengthMenu: [[10, 20, 30, -1], [10, 20, 30, "All"]],
        iDisplayLength: 20,
        sDom: '<"row-fluid"<"span6"l><"span6"f>r>t<"row-fluid"<"span6"i><"span6"p>>',
        sPaginationType: "bootstrap",
        oLanguage:
            sLengthMenu: "_MENU_ 每页",
            oPaginate:
                sPrevious: "",
                sNext: "",
            sEmptyTable: "没有数据"
            sSearch: "搜索:   "
            sInfo: "总共有 _TOTAL_ 条数据"
            sInfoEmpty: ""
            sProcessing: "正在加载中……"
            sInfoFiltered:""
            sZeroRecords:"没有数据"
        aoColumnDefs: [bSortable: false, aTargets: [0]]
    $.extend {}, global, opt

table_update_listener = (res, table, call) ->
    $(res).on "updated", (e, source) ->
        $("#{table}").DataTable().clear().draw()
        $("#{table}").DataTable().destroy()
        call e,source
        $("#{table}").dataTable dtable_opt()
        return

valid_opt = (opt) ->
    global =
        focusInvalid: false
        ignore: ''
        highlight: (elem) -> $(elem).closest('.control-group').addClass('error')
        success: (label) ->
            label.closest('.control-group').removeClass('error')
            label.remove()
        errorPlacement: (error, elem) ->
            error.addClass('help-inline help-small no-left-padding').appendTo(elem.closest('.controls'))
    $.extend {}, global, opt

avalon_templ = (id, src, attr={}) ->
    attr = ("#{k}='#{v}'" for k, v of attr).join(" ")
    """<div id="#{id}" ms-controller="#{id}" ms-include-src="'#{src}'" #{attr}></div>"""

scan_avalon_templ = (vm, id, src, attr={}) ->
    html = avalon_templ id, src, attr
    elem = $(html)[0]
    avalon.scan elem, vm
    return elem

class ChainProgress
    constructor: (@chain, @unblock=true) ->
        @id = random_id "progress-"
        @vm = avalon.define @id, (vm) ->
            vm.ratio = 0

    show: () =>
        if @unblock
            $(@chain).one 'completed', () =>
                @vm.ratio = 100
                setTimeout (=> @hide()), 500
            $(@chain).one 'error', () =>
                @hide()
        $(@chain).on 'progress', (e, a) =>
            @vm.ratio = a.ratio*100

        $.blockUI
            message: scan_avalon_templ @vm, @id, "html/chain_progress.html"
            css:
                padding: '19px'
                border: '0px solid #eee'
                backgroundColor: 'none'

    hide: () =>
        $.unblockUI()
        $("##{@id}").remove()
        delete avalon.vmodels[@id]
        
_show_chain_progress = (cprog, chain, ignore_status_0=false) ->
    cprog.show()
    chain.execute().done ->
        setTimeout (-> $.unblockUI()), 1000
    .fail (status, reason) ->
        setTimeout (->
            switch status
                when 400
                    (new MessageModal(reason.description)).attach()
                else
                    if status == 0 and ignore_status_0
                        break
                    (new MessageModal(reason)).attach()
            $.unblockUI()), 1000

show_chain_progress = (chain, ignore_status_0=false, unblock=true) ->
    cprog = new ChainProgress chain, unblock
    _show_chain_progress cprog, chain, ignore_status_0

class NotificationProgress
    constructor: (@sd, @title="", @unblock=true) ->
        @id = random_id "inprogress-"
        @vm = avalon.define @id, (vm) =>
            vm.ratio = 0
            vm.message = @title

    show: () =>
        if @unblock
            $(@sd).one 'incompleted', (e, event) =>
                @vm.message = event.message
                @vm.ratio = 100
                setTimeout (=> @hide()), 500
        $(@sd).on 'inprogress', (e, event) =>
            @vm.message = event.message
            @vm.ratio = event.ratio*100

        $.blockUI
            message: scan_avalon_templ @vm, @id, "html/notification_progress.html"
            css:
                padding: '19px'
                border: '1px solid #eee'
                backgroundColor: '#fafafa'

    hide: () =>
        $.unblockUI()
        $("##{@id}").remove()
        delete avalon.vmodels[@id]

class AvalonTemplUI
    constructor: (@prefix, @src, @parent_selector, @replace=true, @attr={}) ->
        @has_rendered = false
        @has_frozen = false
        @id = @ctrl = random_id @prefix
        $.extend @attr, "data-include-rendered":"rendered"
        @vm = avalon.define @ctrl, (vm) =>
            vm.rendered = @rendered
            @define_vm(vm)
        @children = []

    define_vm: (vm) =>

    add_child: (child) =>
        @children.push child

    rendered: () =>
        @has_rendered = true

    refresh: () =>
        @attach()

    frozen: () =>
        @has_frozen = true

    attach: () =>
        @has_frozen = false
        if @has_rendered
            @remove()
        if @id not of avalon.vmodels
            avalon.vmodels[@id] = @vm
        parent = $(@parent_selector)
        elem = avalon_templ @ctrl, @src, @attr
        if @replace
            parent.html elem
        else
            parent.append elem
        avalon.scan parent[0], @vm

    detach: () =>
        for child in @children
            child.detach()
        @has_rendered = false
        avalon.vmodels[@id] = null
        delete avalon.vmodels[@id]
        @remove()

    remove: () =>
        $self = $("##{@id}")
        $self.remove()

class HeaderUI extends AvalonTemplUI
    constructor: (@admin, @server) ->
        super "header-", "html/header.html", "#header", false
        @window_manager = new WindowManager
        @vm.show_server = if @server.type == "store" then true else false
        @server.header = false
        
    define_vm: (vm) =>
        vm.lang = lang.header
        vm.slient = @slient
        vm.refresh = @refresh
        vm.broadcast = @broadcast
        vm.add_machine = @add_machine
        vm.server_switch = @server_switch
        vm.mini_window = @mini_window
        vm.close_window = @close_window
        vm.resize_window = @resize_window
        vm.fullscreen = false
        #vm.show_server = @central
        vm.show_server = true
        vm.rendered = @rendered
        vm.change_data = @change_data
        vm.lock = @lock
        vm.change_passwd = @change_passwd
        vm.change_head = @change_head
        vm.register = @register
        vm.facequick = @facequick
        vm.username = ""

    rendered: () =>
        new WOW().init();
        $('.tip-twitter').remove();
        $('.hastip-header').poshytip(
            className: 'tip-twitter'
            showTimeout: 0
            alignTo: 'target',
            alignX: 'center',
            alignY: 'bottom',
            offsetY: 5,
            allowTipHover: false,
            fade: false
        )
        @back_to_top()
        return

    avatar:(host,user) =>
        random = Math.random();
        urls = 'http://' + host + '/downloadAvatar/' + user + '/head/' + user + '_head.jpg';
        $("#user_img_log").attr('src', urls + "?t=" + random);
        #$('#user_img_log').attr('src',urls)

    back_to_top:() =>
        $(`function() {
            if ($('#back-to-top').length) {
                var scrollTrigger = 100, // px
                    backToTop = function () {
                        var scrollTop = $(window).scrollTop();
                        if (scrollTop > scrollTrigger) {
                            $('#back-to-top').addClass('show');
                        } else {
                            $('#back-to-top').removeClass('show');
                        }
                    };
                backToTop();
                $(window).on('scroll', function () {
                    backToTop();
                });
                $('#back-to-top').on('click', function (e) {
                    e.preventDefault();
                    $('html,body').animate({
                        scrollTop: 0
                    }, 700);
                });
            }
        }`)

    lock:() =>
        return

    facequick:() =>
        (new FaceQuickProPage(sds[0], "")).attach()

    register:() =>
        @refresh_facepage()
        (new RegisterPage(sds[0], "")).attach()

    change_head:() =>
        (new RegisterChangeHeadModal(sds[0], new RegisterPage(sds[0], ""))).attach()

    change_passwd:() =>
        (new RegisterChangePasswdModal(sds[0], this)).attach()

    change_data:() =>
        account = sds[0].register.items['account']
        (new RegisterDetailModal(sds[0], this,account)).attach()
        #(new RegisterChangeDataModal(sds[0], this)).attach()

    hide_log: () =>
        $("#log_event").hide()
            
    refresh: ->
        chain = new Chain
        for sd in sds
            chain.chain sd.update("all")
        show_chain_progress(chain).done ->
            console.log "Refresh Storage Data"
        return

    slient: () =>
        @admin.remove_all()
        host = []
        for sd in sds
            if sd.host is "" 
                continue
            else
                if sd.systeminfo.data.version is "UNKOWN"
                    continue
                else
                    host.push sd.host
        
        if host.length == 0
            (new MessageModal(lang.header.beep_need_login)).attach()
        else
            beep = (new CommandRest(host[0]))
            chain = new Chain
            (beep.slient()).done (data) =>
                (new MessageModal lang.header.stop_beep_success).attach()
            .fail (data) =>
                (new MessageModal lang.header.stop_beep_error).attach()
    
    broadcast: () =>
        chain = new Chain()
        bcst = new BCST
        chain.chain bcst.broadcast
        show_chain_progress(chain).done =>
            machines = @_filter_machine bcst
            @_show_bcst_message machines
            ###regex = /^\d{1,3}(\.\d{1,3}){3}$/
            for nav in @admin.vm.navs
                continue if regex.test(nav.title)
                break if machines.length is 0
                device = @admin.deviceviews[nav.menuid]
                device.change_device machines[0]
                machines = machines[1..]###
            for machine in machines
                device = @admin.new_machine true
                device.change_device machine
            return

    server_switch: () =>
        (new ConfirmModal lang.server.warning, =>
            @frozen()
            if @vm.show_server
                @admin.remove_all()
                @vm.show_server = false
                (new ServerUI @server).central()
            else
                @vm.show_server = true
                (new ServerUI @server).store()
        ).attach()

    _show_bcst_message: (machines) ->
        settings = new SettingsManager
        logined = settings.getLoginedMachine()
        if logined.length is 0
            if machines.length is 0
                message = lang.header.detect_no_machines_info
            else
                message = lang.header.detect_machines_info machines.length
        else
            if machines.length is 0
                message = lang.header.detect_no_new_machine_info
            else
                message = lang.header.detect_new_machines_info machines.length
        (new MessageModal message).attach()
        return

    _filter_machine: (bcst) ->
        settings = new SettingsManager
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
        for nav in @admin.vm.navs
            machines.push nav.title if regex.test nav.title
        machines

    add_machine: () =>
        (new ConfirmModal "确定要登出此账号吗?", =>
            @admin.remove_all()
            @admin.new_machine true
            @refresh_facepage()
        ).attach()
        

    refresh_facepage:() =>
        ((window.clearInterval(i)) for i in compare_Interval)
        if compare_card.length
            compare_card.splice(0,compare_card.length)
        if compare_result.length
            compare_result.splice(0,compare_result.length)
        #if compare_Interval.length
        #    compare_Interval.splice(0,compare_Interval.length)
        #window.location.href = "index.html"

    mini_window: () =>
        @window_manager.minimizeWindow()

    close_window: () =>
        @window_manager.closeWindow()

    resize_window: () =>
        if @vm.fullscreen
            @window_manager.unmaximizeWindow()
        else
            @window_manager.maximizeWindow()
        @vm.fullscreen = !@vm.fullscreen

class DeviceView extends AvalonTemplUI
    constructor: (@menuid) ->
        super "submenu-", "html/submenu.html", ".#{@menuid} .sub-menu", false
        @loginpage = new LoginPage(this)
        @login = false
        @cur_page = @loginpage
        @host = ""
        @reconnect = false

    define_vm: (vm) =>
        vm.navs = [{title: lang.sidebar.overview, icon: "icon-dashboard",id: "overview"},
                   {title: lang.sidebar.disk,     icon: "icon-hdd",      id: "disk"},
                   {title: lang.sidebar.raid,     icon: "icon-tasks",    id: "raid"},
                   {title: lang.sidebar.volume,   icon: "icon-list-alt", id: "volume"},
                   {title: lang.sidebar.initr,    icon: "icon-sitemap",  id: "initr"},
                   {title: lang.sidebar.setting,  icon: "icon-cogs",     id: "setting"},
                   {title: lang.sidebar.maintain, icon: "icon-wrench",   id: "maintain"},
                   {title: lang.sidebar.quickmode,icon: "icon-magic",    id: "quickmode"}]
        vm.active_index = 0
        vm.switch_to_page = (e) =>
            @switch_to_page $(e.target).data("id")

    init: (host) =>
        _settings = new (require("settings").Settings)
        port = _settings.port
        @login = true
        @host = host
        @sd = new StorageData("#{host}:" + port)
        @overviewpage  = new OverviewPage(@sd, @switch_to_page)
        @diskpage      = new DiskPage(@sd)
        @raidpage      = new RaidPage(@sd)
        @volumepage    = new VolumePage(@sd)
        @initrpage     = new InitrPage(@sd)
        @settingpage   = new SettingPage(this, @sd)
        @maintainpage  = new MaintainPage(this,@sd)
        @quickmodepage = new QuickModePage(this, @sd)
        @pages = [@overviewpage, @diskpage, @raidpage, @volumepage, @initrpage,\
            @settingpage, @maintainpage, @quickmodepage]

        $(@sd).one "disconnect", @disconnect

        $(".#{@menuid}").addClass "open"
        $(".#{@menuid} .sub-menu").show()
        $(".#{@menuid} a>span:last-child").addClass "arrow open"
        sds.push @sd

        @notification_manager = new NotificationManager @sd
        @notification_manager.notice()
        
        $(@sd).one "user_login", @login_event
        @sd.update "all"

    destroy: =>
        if @login
            (new SettingsManager).removeLoginedMachine @host
            @reconnect = true
            @sd.close_socket()
            arr_remove sds, @sd

    disconnect: (element, host) =>
        if not @reconnect and host is @sd.host
            arr_remove sds, @sd
            (new SettingsManager).removeLoginedMachine @host
            @switch_to_login_page()
            @sd.close_socket()
            (new MessageModal lang.disconnect_warning.disconnect_message).attach()
            return

    login_event: (element, id) =>
        if @token 
            if id isnt @token
                @reconnect = true
                arr_remove sds, @sd
                (new SettingsManager).removeLoginedMachine @host
                @switch_to_login_page()
                @sd.close_socket()
                (new MessageModal (lang.login_by_other_warning @host)).attach()
                return
        
    switch_to_login_page: () =>
        @detach_all_page()
        @login = false
        @loginpage.attach()
        @vm.active_index = 0
        $(".#{@menuid}").removeClass "open"
        $(".#{@menuid} .sub-menu").hide()
        $(".#{@menuid} a>span:last-child").removeClass "arrow open"
        @detach()

    attach: () =>
        if not @login
            @loginpage.attach()
        else
            super()
            @attach_page()

    change_device: (device) =>
        @loginpage.change_device device

    switch_to_page: (pageid) =>
        @vm.active_index = 0
        for nav, idx in @vm.navs
            if nav.id is pageid
                @vm.active_index = idx
        @attach_page()

    attach_page: () =>
        if @cur_page
            @cur_page.detach?()
        @cur_page = @pages[@vm.active_index]
        @cur_page.attach()

    detach_all_page: () =>
        page.detach?() for page in @pages if @pages
        @loginpage.detach?()
        return

class AdminView
    constructor: (@server) ->
        @deviceviews = {}
        @cur_view = null
        newid = random_id 'menu-'
        @vm = avalon.define "sidebar", (vm) =>
            vm.navs = [{title: lang.adminview.menu_new, icon: "icon-home", menuid: "#{newid}"}]
            vm.active_index = 0
            vm.tab_click = @tab_click
            vm.server = "store"
        
        @get_history_machines()
        # 初始化HeaderUI
        if @server.header
            @header = new HeaderUI(this, @server)
            @header.attach()
        else
            @header = new HeaderUI(this, @server)
            @new_machine true
        #@attach_dview @vm.navs[0]

    get_history_machines: () =>
        settings = new SettingsManager
        if settings.getSearchedMachines() and settings.getSearchedMachines().length != 0
            for machine in settings.getSearchedMachines()
                console.log machine
                console.log settings.getSearchedMachines()
                nav = {title: lang.adminview.menu_new, icon: "icon-home"}
                newId = random_id "menu-"
                nav.menuid = newId
                nav.title = machine
                @vm.navs.push nav
                index = @vm.navs.length - 1
                @attach_dview @vm.navs[index]
                @vm.active_index = index
                @deviceviews[newId].change_device machine
        else
            @attach_dview @vm.navs[0]

    tab_click: (e) =>
        index = parseInt e.currentTarget.dataset.idx
        if e.target.className isnt "icon-remove-circle"
            @switch_tab index
            console.log index
        else
            @remove_tab index
                
    remove_all: () =>
        for i in [@vm.navs.length-1..0]
            @remove_tab(i)
        @vm.navs.splice 0, 1
        @deviceviews = {}
            
    remove_tab: (index) =>
        settings = new SettingsManager
        if @vm.navs.length is 1
            target = index
            @new_machine true
        else if index is @vm.navs.length - 1
            target = index - 1
        else
            target = index
        del_nav = @vm.navs[index]
        console.log del_nav
        if index isnt -1 then @vm.navs.splice index, 1
        @switch_tab target
        settings.removeSearchedMachine @vm.navs[index]
        @_del_dview del_nav

    switch_tab: (index) =>
        old_nav = @cur_view
        @vm.active_index = if index? then index else 0
        nav = @vm.navs[@vm.active_index]
        @attach_dview nav

    attach_dview: (nav) =>
        if nav.menuid not of @deviceviews
            dview = new DeviceView(nav.menuid)
            @deviceviews[nav.menuid] = dview
            
            dview.loginpage.vm.$watch "device", (nval, oval) ->
                if nval isnt ""
                    nav.title = nval
                else
                    nav.title = lang.adminview.menu_new
            
        new_view = @deviceviews[nav.menuid]
        if new_view is @cur_view
            return

        if @cur_view
            @cur_view.detach_all_page?()
            @cur_view.detach?()
        @cur_view = new_view
        @cur_view.attach()

    _del_dview: (nav) =>
        if nav.menuid not of @deviceviews
            return
        dview = @deviceviews[nav.menuid]
        #console.log dview
        dview.destroy()
        return

    new_machine: (is_bcst) =>
        menuid = @_new_machine {title: lang.adminview.menu_new, icon: "icon-home"}, is_bcst
        #console.log menuid
        @deviceviews[menuid]

    _new_machine: (nav, is_bcst) =>
        #console.log @cur_view.login
        if @cur_view.login is false and not is_bcst
            cur_nav = @vm.navs[@vm.active_index]
            return cur_nav.menuid
        newId = random_id "menu-"
        nav.menuid = newId
        @vm.navs.push nav
        index = @vm.navs.length - 1
        @vm.active_index = index
        @attach_dview @vm.navs[index]
        nav.menuid

    find_nav_index: (menuid) =>
        for nav, index in @vm.navs
            return index if nav.menuid is menuid
        -1
        
class CentralDeviceView extends AvalonTemplUI
    constructor: (@menuid) ->
        super "submenu-", "html/submenu_central.html", ".#{@menuid} .sub-menu", false
        @loginpage = new CentralLoginPage(this)
        @login = false
        @cur_page = @loginpage
        @host = ""
        @user = ""
        @reconnect = false
        @user_name = ""
        
    define_vm: (vm) =>
        #vm.navs = [{title: '数据统计', icon: "icon-graph",   id: "count"}]

        vm.navs = [{title: '基本功能', icon: "icon-magic-wand",   id: "Facedetect"}]
                   ##{title: '基本资料', icon: "icon-user", id: "basicdata"}]
                   ##{title: '基本功能', icon: "icon-magic-wand",   id: "Facedetect"}]
                   ##{title: '数据统计', icon: "icon-graph",   id: "count"},
                   ##{title: '管理后台', icon: "icon-settings",   id: "manager"}

        ###
        vm.navs = [{title: lang.centralsidebar.overview, icon: "icon-graph", id: "overview"},
                   {title: lang.centralsidebar.monitor, icon: "icon-bar-chart",   id: "monitor"},
                   {title: lang.centralsidebar.base, icon: "icon-layers", id: "base"},
                   {title: lang.centralsidebar.warn, icon: "icon-bell", id: "warning"}]###
                   
        vm.navs_overview = [{title: lang.centralsidebar.overview_store, icon: "icon-briefcase", id: "store_overview"},
                           {title: lang.centralsidebar.overview_server, icon: " icon-briefcase", id: "server_overview"}
                        ]
        vm.navs_monitor = [{title: lang.centralsidebar.store_monitor, icon: "icon-briefcase", id: "store_monitor"},
                         {title: lang.centralsidebar.server_monitor, icon: " icon-briefcase", id: "server_monitor"}
                        ]
        vm.navs_base = [{title: lang.centralsidebar.serverlist, icon: "icon-briefcase", id: "serverlist"},
                        {title: lang.centralsidebar.storelist, icon: "icon-briefcase", id: "storelist"},
                        {title: lang.centralsidebar.clientlist, icon: "icon-briefcase", id: "clientlist"}]
                        
        vm.active_index = 0
        vm.active_index_overview = 0
        vm.active_index_monitor = 0
        vm.active_index_base = 0
        
        vm.switch_to_page = (e) =>
            @switch_to_page $(e.target).data("id")
        vm.switch_to_page_overview = (s) =>
            @switch_to_page_overview $(s.target).data("id")
        vm.switch_to_page_monitor = (i) =>
            @switch_to_page_monitor $(i.target).data("id")
        vm.switch_to_page_base = (t) =>
            @switch_to_page_base $(t.target).data("id")
            
        vm.open_overview = @open_overview
        vm.open_monitor = @open_monitor
        vm.open_base = @open_base
        vm.user_name = @user_name
        
    init: (host,user) =>
        _settings = new (require("settings").Settings)
        $(".page-content").css("background-color","#f7f8fa");
        $('.menu-toggler').attr('style', 'display:block');
        $('.navbar-fixed-top').attr('style', 'display:block');
        $('#user_setting').attr('style', 'display:block');
        
        #$('.page-header-fixed').attr('style', 'background:#3D3D3D !important');
        #$(".page-header-fixed").css("background-color","#3D3D3D");
        port = _settings.port
        @login = true
        @host = host
        @user = user
        @sd = new CentralStorageData("#{host}:" + port,user)
        ###
        @centralserverviewpage = new CentralServerViewPage(@sd, @switch_to_page)
        @centralstoreviewpage = new CentralStoreViewPage(@sd, @switch_to_page)
        @centralstoremonitorpage = new CentralStoremonitorPage(@sd, @switch_to_page_monitor)
        @centralservermonitorpage = new CentralServermonitorPage(@sd, @switch_to_page_monitor)
        @centralserverlistpage = new CentralServerlistPage(@sd)
        @centralstorelistpage = new CentralStorelistPage(@sd)
        @centralclientpage = new CentralClientlistPage(@sd)
        @centralwarningpage = new CentralWarningPage(@sd)
        @centralmonitorpage = new CentralMonitorPage(@sd, @switch_to_page)###

        @registerpage = new RegisterPage(@sd, @switch_to_page)
        #@facepage = new FacePage(@sd, @switch_to_page)
        @countpage = new PreCountPage(@sd,@switch_to_page)
        @managerpage = new ManagerPage(@sd, @switch_to_page)
        #@facequickpage = new FaceQuickPage(@sd, @switch_to_page)
        @facequickpropage = new FaceQuickProPage(@sd, @switch_to_page)
        
        @pages = [ @facequickpropage]
        @pages_title = [@facequickpropage]

        #@pages = [@registerpage, @facequickpropage,@countpage,@managerpage]
        #@pages_title = [@registerpage, @facequickpropage,@countpage,@managerpage]

        #@pages = [@countpage]
        #@pages_title = [@countpage]

        ###@pages = [@centralserverviewpage, @centralstoreviewpage, @centralmonitorpage , @centralserverlistpage, @centralstorelistpage, @centralclientpage,@centralwarningpage ]
        @pages_title = [@centralstoreviewpage, @centralmonitorpage, @centralserverlistpage, @centralwarningpage]
        @pages_overview = [@centralstoreviewpage, @centralserverviewpage]
        #@pages_monitor = [@centralstoremonitorpage , @centralservermonitorpage]
        @pages_base =  [@centralserverlistpage, @centralstorelistpage, @centralclientpage]###
        $(@sd).one "disconnect", @disconnect

        $(".#{@menuid}").addClass "open"
        $(".#{@menuid} .sub-menu").show()
        $(".#{@menuid} a>span:last-child").addClass "arrow open"
        
        sds.push @sd
        @notification_manager = new NotificationManager @sd
        @notification_manager.notice()
        $(@sd).one "user_login", @login_event
        @sd.update "all"
      
    open_overview: (id)=>
        if id is "overview" then true else false
    open_monitor: (id)=>
        if id is "monitor" then true else false
    open_base: (id)=>
        if id is "base" then true else false

    destroy: =>
        if @login
            (new SettingsManager).removeLoginedMachine @host
            @reconnect = true
            @sd.close_socket()
            arr_remove sds, @sd
            
    disconnect: (element, host) =>
        if not @reconnect and host is @sd.host
            arr_remove sds, @sd
            (new SettingsManager).removeLoginedMachine @host
            @switch_to_login_page()
            @sd.close_socket()
            (new MessageModal lang.disconnect_warning.disconnect_message).attach()
            server = {}
            @log = new HeaderUI(@sd,server)
            @log.hide_log()
            return

    switch_remove:() =>
        $(".#{@menuid} .sub-menu li").removeClass "open"
        $(".#{@menuid} .sub-menu li>ul").css('display','none')

    login_event: (element, data) =>
        console.log data.confidence
        console.log element
        console.log data.uuid
        if @token
            if data.confidence isnt "" and data.confidence isnt @token
                @reconnect = true
                arr_remove sds, @sd
                (new SettingsManager).removeLoginedMachine @host
                @switch_to_login_page()
                @sd.close_socket()
                (new MessageModal (lang.login_by_other_warning @user)).attach()
                return
        
    switch_to_login_page: () =>
        @detach_all_page()
        @login = false
        @loginpage.attach()
        @vm.active_index = 0
        $(".#{@menuid}").removeClass "open"
        $(".#{@menuid} .sub-menu").hide()
        $(".#{@menuid} a>span:last-child").removeClass "arrow open"
        @detach()

    attach: () =>
        if not @login
            @loginpage.attach()
        else
            super()
            @attach_page()

    change_device: (device) =>
        @loginpage.change_device device

    switch_remove:() =>
        $(".#{@menuid} .sub-menu li").removeClass "open"
        $(".#{@menuid} .sub-menu li>ul").css('display','none')

    switch_to_page: (pageid) =>
        
        ((window.clearInterval(i)) for i in compare_Interval)
        if compare_Interval.length
            compare_Interval.splice(0,compare_Interval.length)
            
        ((window.clearInterval(i)) for i in global_Interval)
        if global_Interval.length
            global_Interval.splice(0,global_Interval.length)
        mainpage = ['basicdata','Facedetect']
        if pageid is "overview"
            @vm.active_index = 0
            @vm.active_index_overview = 0
            @attach_page_overview()
        #else if pageid is "monitor"
        #    @vm.active_index = 1
        #    @vm.active_index_monitor = 0
        #    @attach_page_monitor()
        else if pageid is "base"
            @vm.active_index = 2
            @vm.active_index_base = 0
            @attach_page_base()
        else
            for nav, idx in @vm.navs
                if nav.id is pageid
                    @vm.active_index = idx
                    @attach_page()
        if pageid in mainpage
            @switch_remove()
                    
    switch_to_page_overview: (pageid) =>
        @vm.active_index = 0
        for nav, idx in @vm.navs_overview
            if nav.id is pageid
                @vm.active_index_overview = idx
        @attach_page_overview()
        
    switch_to_page_monitor: (pageid) =>
        @vm.active_index = 1
        for nav, idx in @vm.navs_monitor
            if nav.id is pageid
                @vm.active_index_monitor = idx
        @attach_page_monitor()
        
    switch_to_page_base: (pageid) =>
        @vm.active_index = 2
        for nav, idx in @vm.navs_base
            if nav.id is pageid
                @vm.active_index_base = idx
        @attach_page_base()
  
    switch_tab: (index) =>
        old_nav = @cur_view
        @vm.active_index = if index? then index else 0
        nav = @vm.navs[@vm.active_index]
        @attach_dview nav

    attach_dview: (nav) =>
        if nav.menuid not of @deviceviews
            dview = new DeviceView(nav.menuid)
            @deviceviews[nav.menuid] = dview
            dview.loginpage.vm.$watch "device", (nval, oval) ->
                if nval isnt ""
                    nav.title = nval
                else
                    nav.title = lang.adminview.menu_new
            
        new_view = @deviceviews[nav.menuid]
        if new_view is @cur_view
            return

        if @cur_view
            @cur_view.detach_all_page?()
            @cur_view.detach?()
        @cur_view = new_view
        @cur_view.attach()
        
    attach_page: () =>
        if @cur_page
            @cur_page.detach?()
        @cur_page = @pages_title[@vm.active_index]
        @cur_page.attach()
        
    attach_page_overview: () =>
        if @cur_page
            @cur_page.detach?()
        @cur_page = @pages_overview[@vm.active_index_overview]
        @cur_page.attach()
        
    attach_page_monitor: () =>
        if @cur_page
            @cur_page.detach?()
        @cur_page = @pages_monitor[@vm.active_index_monitor]
        @cur_page.attach()
        
    attach_page_base: () =>
        if @cur_page
            @cur_page.detach?()
        @cur_page = @pages_base[@vm.active_index_base]
        @cur_page.attach()
        
    detach_all_page: () =>
        page.detach?() for page in @pages if @pages
        @loginpage.detach?()
        return

class CentralView
    constructor: (@server) ->
        @deviceviews = {}
        @cur_view = null
        newid = random_id 'menu-'
        @vm = avalon.define "sidebar", (vm) =>
            vm.navs = [{title: lang.server.centre, icon: "icon-home", menuid: "#{newid}"}]
            vm.active_index = 0
            vm.tab_click = @tab_click
            vm.server = "central"
        
        # 初始化HeaderUI
        #if @reheader
        if @server.header
            @header = new HeaderUI(this, @server)
            @header.attach()
        else
            console.log "store -->central"
            @header = new HeaderUI(this, @server)
        
        @attach_dview @vm.navs[0]
        
    tab_click: (e) =>
        index = parseInt e.currentTarget.dataset.idx
        if e.target.className isnt "icon-remove-circle"
            @switch_tab index
        else
            @remove_tab index
                
    remove_all: () =>
        for i in [@vm.navs.length-1..0]
            del_nav = @vm.navs[i]
            if i isnt -1 then @vm.navs.splice i, 1
            if del_nav isnt undefined then @_del_dview del_nav
            #@_del_dview del_nav
            
    remove_tab: (index) =>
        settings = new SettingsManager
        if @vm.navs.length is 1
            target = index
            @new_machine true
        else if index is @vm.navs.length - 1
            target = index - 1
        else
            target = index
        del_nav = @vm.navs[index]
        console.log del_nav
        if index isnt -1 then @vm.navs.splice index, 1
        @switch_tab target
        settings.removeSearchedMachine @vm.navs[index]
        @_del_dview del_nav

    switch_tab: (index) =>
        old_nav = @cur_view
        @vm.active_index = if index? then index else 0
        nav = @vm.navs[@vm.active_index]
        @attach_dview nav

    attach_dview: (nav) =>
        if nav.menuid not of @deviceviews
            dview = new CentralDeviceView(nav.menuid)
            @deviceviews[nav.menuid] = dview
            
            dview.loginpage.vm.$watch "device", (nval, oval) ->
                if nval isnt ""
                    nav.title = nval
                else
                    nav.title = lang.adminview.menu_new
            
        new_view = @deviceviews[nav.menuid]
        if new_view is @cur_view
            return

        if @cur_view
            @cur_view.detach_all_page?()
            @cur_view.detach?()
        @cur_view = new_view
        @cur_view.attach()

    _del_dview: (nav) =>
        if nav.menuid not of @deviceviews
            return
        dview = @deviceviews[nav.menuid]
        #console.log dview
        dview.destroy()
        return

    new_machine: (is_bcst) =>
        menuid = @_new_machine {title: lang.adminview.menu_new, icon: "icon-home"}, is_bcst
        #console.log menuid
        @deviceviews[menuid]

    _new_machine: (nav, is_bcst) =>
        #console.log @cur_view.login
        if @cur_view.login is false and not is_bcst
            cur_nav = @vm.navs[@vm.active_index]
            return cur_nav.menuid
        newId = random_id "menu-"
        nav.menuid = newId
        @vm.navs.push nav
        index = @vm.navs.length - 1
        @vm.active_index = index
        @attach_dview @vm.navs[index]
        nav.menuid

    find_nav_index: (menuid) =>
        for nav, index in @vm.navs
            return index if nav.menuid is menuid
        -1
                    
this.AdminView = AdminView
this.AvalonTemplUI = AvalonTemplUI
this.CentralView = CentralView
this.CentralDeviceView = CentralDeviceView
this.ChainProgress = ChainProgress
this.DeviceView = DeviceView
this.HeaderUI = HeaderUI
this.NotificationProgress = NotificationProgress
this.valid_opt = valid_opt
this._show_chain_progress = _show_chain_progress
this.avalon_templ = avalon_templ
this.dtable_opt = dtable_opt
this.scan_avalon_templ = scan_avalon_templ
this.show_chain_progress = show_chain_progress
this.table_update_listener = table_update_listener
