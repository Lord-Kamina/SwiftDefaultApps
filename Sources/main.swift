/*
 * ----------------------------------------------------------------------------
 * "THE BEER-WARE LICENSE" (Revision 42):
 * <g.litenstein@gmail.com> wrote this file. As long as you retain this notice you
 * can do whatever you want with this stuff. If we meet some day, and you think
 * this stuff is worth it, you can buy me a beer in return., Gregorio Litenstein.
 * ----------------------------------------------------------------------------
 */

import Foundation
import SwiftCLI

let bundle = Bundle.init(url: URL(string:"file:///Applications/iTunes.app/")!)

    
//var test = CopyHandlerForUTI("public.data", LSRolesMask.all)
//
//test = CopyHandlerForUTI("", LSRolesMask.all)
//
//let test2 = CopyAllHandlersForUTI("public.png", LSRolesMask.all)
//let test3 = UTTypeFuncs().copyAllHandlersAsString("public.png", LSRolesMask.all)

LSWrappers.Schemes().setDefaultHandler("+magnet","com.barebones.bbedit")

LSWrappers.Schemes().setDefaultHandler("magnet","http://www.google.com")

LSWrappers.Schemes().setDefaultHandler("magnet","file:/http://www.google.com")

LSWrappers.Schemes().setDefaultHandler("magnet","file://http://www.google.com")

LSWrappers.Schemes().setDefaultHandler("magnet","com.barebones.bbedit")

LSWrappers.Schemes().setDefaultHandler("magnet","/Applications/BBEdit.app")


LSWrappers.UTType().setDefaultHandler("magnet","public.html")

LSWrappers.Schemes().setDefaultHandler("magnet","com.barebones.bbedit")

LSWrappers.UTType().setDefaultHandler("public.html","com.barebones.bbedit")

CLI.setup(name:"lsreg")

CLI.register(commands: [ ReadCommand(), GetApps(), GetSchemes(), GetUTIs() ])

CLI.debugGo(with: "lsreg getUTIs")

CLI.debugGo(with: "lsreg getSchemes")

CLI.debugGo(with: "lsreg getHandler --UTI public.text")

CLI.debugGo(with: "lsreg getHandler --browser")

CLI.debugGo(with: "lsreg getHandler --internet")

CLI.debugGo(with: "lsreg getHandler --URL public.jpeg")

//
CLI.debugGo(with: "lsreg getHandler --URL public.jpeg --all")
CLI.debugGo(with: "lsreg getHandler --UTI public.png --all")
