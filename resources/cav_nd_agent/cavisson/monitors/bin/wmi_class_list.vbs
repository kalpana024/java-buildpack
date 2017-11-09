strComputer = "."
strName=""
Set objWMIService=GetObject("winmgmts:{impersonationLevel=impersonate}!\\" & _ 
    strComputer & "\root\cimv2")
 
For Each objclass in objWMIService.SubclassesOf()
     strName=ucase(objClass.Path_.Class)
    if instr (strName, "ASP") > 0 then
        Wscript.Echo objClass.Path_.Class
    end if                
Next
