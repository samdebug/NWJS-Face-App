sds = []

$ ->
    avalon.config loader: false
    
    @serverUI=server_type
    @serverUI.type = 'central'
    @serverUI.store = false
    
    window.adminview = new CentralView(@serverUI)
    avalon.scan()

    App.init()
    #(new ServerUI).attach()
    $.fn.modalmanager.defaults.resize = true

    $.validator.addMethod 'duplicated', (val, elem, items) ->
        return (e for e in items when e.name is val or e.wwn is val).length is 0

    $.validator.addMethod("regex", (val, elem, regexp) ->
        re = new RegExp(regexp)
        this.optional(elem) || re.test(val)
    , "输入格式不正确")

    HotKeyManager.hotkey()

this.sds = sds
