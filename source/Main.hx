package;

import lime.system.System;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.UncaughtErrorEvent;
import openfl.Lib;

import flixel.FlxG;
import flixel.FlxGame;
import flixel.FlxState;

import funkin.ui.FullScreenScaleMode;
import funkin.Preferences;
import funkin.PlayerSettings;
import funkin.util.logging.CrashHandler;
import funkin.ui.debug.FunkinDebugDisplay;
import funkin.ui.debug.FunkinDebugDisplay.DebugDisplayMode;
import funkin.save.Save;
import funkin.util.WindowUtil;

#if hxvlc
import hxvlc.util.Handle;
#end

using funkin.util.AnsiUtil;

class Main extends Sprite
{
  var gameWidth:Int = 1280;
  var gameHeight:Int = 720;
  var initialState:Class<FlxState> = funkin.InitState;
  var zoom:Float = -1;
  var skipSplash:Bool = true;

  public static var debugDisplay:FunkinDebugDisplay;

  public static function main():Void
  {
    #if android
    Sys.setCwd(haxe.io.Path.addTrailingSlash(extension.androidtools.content.Context.getExternalFilesDir()));
    #elseif ios
    Sys.setCwd(haxe.io.Path.addTrailingSlash(System.documentsDirectory));
    #end

    CrashHandler.initialize();
    CrashHandler.queryStatus();
    Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, function(e)
    {
      trace(' CRASH '.bold().bg_red() + Std.string(e.error));
    });

    Lib.current.addChild(new Main());
  }

  public function new()
  {
    super();

    haxe.Log.trace = funkin.util.logging.AnsiTrace.trace;
    funkin.util.logging.AnsiTrace.traceBF();

    openfl.utils._internal.Log.level = openfl.utils._internal.Log.LogLevel.ERROR;

    funkin.modding.PolymodHandler.loadAllMods();

    if (stage != null) init();
    else addEventListener(Event.ADDED_TO_STAGE, init);
  }

  function init(?event:Event):Void
  {
    if (hasEventListener(Event.ADDED_TO_STAGE))
      removeEventListener(Event.ADDED_TO_STAGE, init);

    setupWindow();
    checkRenderer();
    setupGame();
  }

  function setupWindow():Void
  {
    #if (sys && !mobile)
    var win = Lib.current.stage.window;

    win.onClose.add(function()
    {
      trace(' EXIT '.bold().bg_red());

      #if hxvlc
      Handle.dispose();
      #end

      Sys.exit(0);
    });

    win.onFocusOut.add(function()
    {
      FlxG.autoPause = true;
      trace(' PAUSED (FOCUS LOST) '.bg_yellow());
    });

    win.onFocusIn.add(function()
    {
      FlxG.autoPause = false;
      trace(' RESUMED '.bg_green());
    });
    #end
  }

  function checkRenderer():Void
  {
    var context = stage.window.context.type;

    if (context != WEBGL && context != OPENGL && context != OPENGLES)
    {
      WindowUtil.showError("Graphics Error",
        "Your GPU does not support required OpenGL/WebGL.");
      System.exit(1);
    }
  }

  function setupGame():Void
  {
    Save.load();

    #if hxvlc
    Handle.initAsync(function(success:Bool)
    {
      trace(success ? "VLC OK" : "VLC FAIL");
    });
    #end

    WindowUtil.setVSyncMode(Preferences.vsyncMode);

    untyped FlxG.cameras = new funkin.graphics.FunkinCameraFrontEnd();

    var framerate:Int = Preferences.unlockedFramerate ? 0 : Preferences.framerate;

    var game = new FlxGame(
      gameWidth,
      gameHeight,
      initialState,
      framerate,
      framerate,
      skipSplash,
      (FlxG.stage.window.fullscreen || Preferences.autoFullscreen)
    );

    @:privateAccess
    game._customSoundTray = funkin.ui.options.FunkinSoundTray;

    addChild(game);

    FlxG.scaleMode = new FullScreenScaleMode();

    debugDisplay = new FunkinDebugDisplay(10, 10, 0xFFFFFF);
    FlxG.signals.postUpdate.add(handleDebugDisplayKeys);

    setupPerformance();
  }

  function setupPerformance():Void
  {
    // Garbage Collector tuning
    #if cpp
    cpp.vm.Gc.enable(true);
    cpp.vm.Gc.setMinimumFreeSpace(20 * 1024 * 1024);
    #end

    // FPS fix
    FlxG.fixedTimestep = false;
    FlxG.updateFramerate = 60;
    FlxG.drawFramerate = 60;

    trace(' PERFORMANCE MODE ENABLED '.bg_blue());
  }

  function handleDebugDisplayKeys():Void
  {
    if (PlayerSettings.player1.controls == null ||
        !PlayerSettings.player1.controls.check(DEBUG_DISPLAY)) return;

    Preferences.debugDisplay = switch (Preferences.debugDisplay)
    {
      case Off: Simple;
      case Simple: Advanced;
      case Advanced: Off;
    };
  }
}