package com.cavisson.monitor.agent;
import java.util.Iterator;
import java.util.Map;
import java.util.Map.Entry;
import monitor.common.CmonConfig;
import monitor.common.CmonLog;
import monitor.common.CmonUtils;

public class CavmonAgentStarter extends Thread
{
  private static CmonConfig cmonConfig = null;
  private static CmonLog cmonLog = null;
  private static String className = "CavmonAgentStarter";
  private CmonUtils cmonUtils = null;
  
  public CavmonAgentStarter()
  {
    cmonConfig = new CmonConfig();
    cmonConfig.addConfigParam("logFilePath", "logs");
    cmonLog = new CmonLog("CavMonAgentDebug.log", "CavMonAgentError.log", cmonConfig);
    cmonUtils = new CmonUtils(cmonConfig, cmonLog, className);
  }
  
  public static void startCavMonAgentServer()
  {
   
    Map<String, String> envProperties = System.getenv();
    
    Iterator<Entry<String, String>> itr = envProperties.entrySet().iterator();
    
    while(itr.hasNext())
    {
      Entry<String, String> entry = itr.next();
      System.setProperty(entry.getKey(), entry.getValue());
    }

    CavmonAgentStarter starter = new CavmonAgentStarter();
    Thread starterThread =  new Thread(starter, "CavMonAgentStarterThread");
    starterThread.start();
  }
  
  public void run()
  {
    cmonLog.debugLog(className, "run", "", "", "method called to launch cavmon agent server.");
    
    try
    {
      CavMonAgent cmonAgent = new CavMonAgent();
      CavMonAgent.isListenModeEnabled = false;
      cmonUtils .logAllProperties();
      cmonAgent.Listener();
       
    }
    catch(Exception ex)
    {
      cmonLog.stackTraceLog(className, "", "", "", "Exception in launching cavmon agent.", ex);
    }
  }

  public static void main(String args[])
  {
    startCavMonAgentServer();     
  }
  
}

