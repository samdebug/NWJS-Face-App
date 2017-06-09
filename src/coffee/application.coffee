class BCST
    constructor: () ->
        @dfd = $.Deferred()
        @client = (require('broadcast').BCST_FACTORY)()
        
    broadcast: () =>
        @client.broadcast 2000, @dfd

    getDetachMachines: () =>
        @client.getDetachMachines()

    getMachines: () =>
        @client.getMachines()

    isContained: (ip) =>
        @client.isContained ip

class SettingsManager
    constructor: ->
        @storage = new StorageHelper

    getUsedMachines: =>
        @storage.getItem "usedMachines"

    addUsedMachine: (ip) =>
        temp = @storage.getItem "usedMachines"
        if not temp
            temp = []
        if temp.indexOf(ip) is -1
            temp.push ip
        @storage.setItem "usedMachines", temp
        return

    removeUsedMachine: (ip) =>
        temp = @storage.getItem "usedMachines"
        if not temp || temp.length is 0
            return
        index = temp.indexOf ip
        temp.splice index, 1
        @storage.setItem "usedMachines", temp
        return

    getSearchedMachines: =>
        @storage.getItem "searchedMachines"

    addSearchedMachine: (ip) =>
        temp = @storage.getItem "searchedMachines"
        if not temp
            temp = []
        if temp.indexOf(ip) is -1
            temp.push ip
        @storage.setItem "searchedMachines", temp
        return

    removeSearchedMachine: (ip) =>
        temp = @storage.getItem "searchedMachines"
        if not temp || temp.length is 0
            return
        index = temp.indexOf ip
        temp.splice index, 1
        @storage.setItem "searchedMachines", temp
        return

    isLoginedMachine: (ip) =>
        machines = @storage.getTempItem "LoginedMachines"
        if machines then ip in machines else false

    addLoginedMachine: (ip) =>
        temp = @storage.getTempItem "LoginedMachines"
        if not temp
            temp = []
        if temp.indexOf(ip) is -1
            temp.push ip
        @storage.setTempItem "LoginedMachines", temp
        return

    removeLoginedMachine: (ip) =>
        temp = @storage.getTempItem "LoginedMachines"
        if not temp || temp.length is 0
            return
        # temp.pop ip if ip in temp
        index = temp.indexOf ip
        temp.splice index, 1
        @storage.setTempItem "LoginedMachines", temp
        return

    getLoginedMachine: =>
        temp = @storage.getTempItem "LoginedMachines"
        temp = [] if not temp
        temp

    localIP: ->
        system = new (require("system").SystemInfo)()
        iface.address for iface in system.getNetList()

class StorageHelper
    constructor: ->
        @_db = window.localStorage
        @_temp_db = window.sessionStorage

    getItem: (key) =>
        temp = @_db[key]
        if temp
            temp = JSON.parse @_db[key]
            return temp[key]
        temp

    getTempItem: (key) =>
        temp = @_temp_db[key]
        if temp
            temp = JSON.parse @_temp_db[key]
            return temp[key]
        temp

    setTempItem: (key, value) =>
        if value
            temp = {}
            temp[key] = value
            @_temp_db[key] = JSON.stringify temp
        return

    setItem: (key, value) =>
        if value
            temp = {}
            temp[key] = value
            @_db[key] = JSON.stringify temp
        return

    removeItem: (key) =>
        @_db.removeItem key
        return

    removeTempItem: (key) =>
        @_temp_db.removeItem key
        return

    clearStorage: =>
        @_db.clear()
        @_temp_db.clear()
        return

class IScSiManager
    constructor: ->
        SystemInfo = require("system").SystemInfo
        @_system = new SystemInfo
        @_iscsi = require "iscsi"

    iScSiAvalable: =>
        if @_system.getLocalSystem() isnt "win32"
            return false
        else
            try
                version = navigator.userAgent.split("\ ")[3]
                version = parseFloat version
                if version >= 6.0
                    return true
                else
                    return false
            catch error
                console.log error
                return false
              
    connect: (initr, ip) =>
        if @iScSiAvalable()
            try
                @_iscsi.init initr, ip
                return true
            catch err
                console.log err
                return false
                
    linkinit: (initr,ip) =>
        @_iscsi.linkinit initr, ip
        
    mark: () =>
        try
            console.log 999
            @_iscsi.mark
        catch e
            console.log e
        
    disconnect: (initr, ip) =>
        if @iScSiAvalable()
            try
                @_iscsi.disinit initr, ip
                return true
            catch err
                console.log err
                return false
            
class HotKeyManager
    @hotkey: ->
        document.addEventListener "keyup", @_keyup, false

    @_keyup: (event) =>
        if event.keyCode is 112
            (new WindowManager).openDevTools()
            @_stop_bubble event

    @_stop_bubble: (event) ->
        event.stopPropagation()

class WindowManager
    constructor: () ->
        @_gui = require 'nw.gui'
        @_cur_window = @_gui.Window.get()

    minimizeWindow: () =>
        @_cur_window.minimize()

    maximizeWindow: () =>

        @_cur_window.maximize()

    unmaximizeWindow: () =>
        @_cur_window.unmaximize()
    
    closeWindow: () =>
        @_cur_window.close()

    openDevTools: () =>
        @_cur_window.showDevTools()

class NotificationManager
    constructor: (@sd) ->
        @task_id = -1

    notice: ->
        $(@sd).on "notification", (e, event) =>
            @_message event.message if event.tpye is "message"
            @_progress event if event.type is "progress"

    _message: (message) ->
        (new MessageModal message).attach()

    _progress: (event) =>
        if @task_id isnt event.id
            @task_id = event.id
            @_new_progress event.message
        else if event.status is "inprogress"
            $(@sd).triggerHandler "inprogress",
                message: event.message
                ratio: event.ratio
        else if event.status is "completed"
            $(@sd).triggerHandler "incompleted", message: event.message

    _new_progress: (message) =>
        progress = new NotificationProgress @sd, message
        progress.show()

class CameraManager
    constructor: ->
        @_cam = require "camera"

    connect_ipcam:(url) =>
        try
            @_cam.connectcam url
        catch err
            console.log err

this.CameraManager = CameraManager
#####################################
this.BCST = BCST
this.HotKeyManager = HotKeyManager
this.IScSiManager = IScSiManager
this.NotificationManager = NotificationManager
this.SettingsManager = SettingsManager
this.StorageHelper = StorageHelper
this.WindowManager = WindowManager
