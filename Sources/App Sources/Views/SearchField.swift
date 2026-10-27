/*
* ----------------------------------------------------------------------------
* "THE BEER-WARE LICENSE" (Revision 42):
* <g.litenstein@gmail.com> wrote this file. As long as you retain this notice you
* can do whatever you want with this stuff. If we meet some day, and you think
* this stuff is worth it, you can buy me a beer in return., Gregorio Litenstein.
* ----------------------------------------------------------------------------
*/

import SwiftUI

/** Native NSSearchField; ↑/↓ move the list selection without leaving the field. */
@MainActor
struct SearchField: NSViewRepresentable {
	@Binding var text: String
	var prompt: String
	var onMove: @MainActor (Int) -> Void

	func makeNSView(context: Context) -> NSSearchField {
		let field = NSSearchField()
		field.placeholderString = prompt
		field.sendsSearchStringImmediately = true
		field.delegate = context.coordinator
		return field
	}

	func updateNSView(_ field: NSSearchField, context: Context) {
		context.coordinator.parent = self
		if field.stringValue != text { field.stringValue = text }
	}

	func makeCoordinator() -> Coordinator { Coordinator(self) }

	@MainActor
	final class Coordinator: NSObject, NSSearchFieldDelegate {
		var parent: SearchField
		init(_ parent: SearchField) { self.parent = parent }

		func controlTextDidChange(_ notification: Notification) {
			guard let field = notification.object as? NSSearchField else { return }
			parent.text = field.stringValue
		}

		func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
			switch selector {
			case #selector(NSResponder.moveUp(_:)): parent.onMove(-1); return true
			case #selector(NSResponder.moveDown(_:)): parent.onMove(1); return true
			default: return false
			}
		}
	}
}
