import Foundation
import SwiftCLI

//var test = CopyHandlerForUTI("public.data", LSRolesMask.all)
//
//test = CopyHandlerForUTI("", LSRolesMask.all)
//
//let test2 = CopyAllHandlersForUTI("public.png", LSRolesMask.all)
//let test3 = UTTypeFuncs().copyAllHandlersAsString("public.png", LSRolesMask.all)

CLI.setup(name:"lsreg")

CLI.register(commands: [ ReadCommand(), GetApps(), GetSchemes(), GetUTIs() ])

CLI.debugGo(with: "lsreg getUTIs")

CLI.debugGo(with: "lsreg getSchemes")

CLI.debugGo(with: "lsreg getApps")

CLI.debugGo(with: "lsreg getHandler --UTI public.text")

CLI.debugGo(with: "lsreg getHandler --browser")

CLI.debugGo(with: "lsreg getHandler --internet")

CLI.debugGo(with: "lsreg getHandler --URL public.jpeg")

CLI.debugGo(with: "lsreg getHandler --what")

CLI.debugGo(with: "lsreg -h")
//
CLI.debugGo(with: "lsreg getHandler --URL public.jpeg --all")
CLI.debugGo(with: "lsreg getHandler --UTI public.png --all")
