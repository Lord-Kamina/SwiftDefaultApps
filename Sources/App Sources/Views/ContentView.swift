/*
* ----------------------------------------------------------------------------
* "THE BEER-WARE LICENSE" (Revision 42):
* <g.litenstein@gmail.com> wrote this file. As long as you retain this notice you
* can do whatever you want with this stuff. If we meet some day, and you think
* this stuff is worth it, you can buy me a beer in return., Gregorio Litenstein.
* ----------------------------------------------------------------------------
*/

import SwiftUI

/** Root view. Every region stretches with its container. */
@MainActor
struct ContentView: View {
	@EnvironmentObject private var model: AppModel

	var body: some View {
		HStack(spacing: 0) {
			SidebarView()
				.frame(width: 240)
			Divider()
			DetailView()
				.frame(maxWidth: .infinity, maxHeight: .infinity)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.toolbar {
			ToolbarItem(placement: .principal) {
				Picker("Category", selection: $model.category) {
					ForEach(Category.allCases) { Text($0.rawValue).tag($0) }
				}
				.pickerStyle(.segmented)
				.labelsHidden()
				.fixedSize()
			}
		}
		.alert("Couldn't Change the Default Application", isPresented: Binding(
			get: { model.errorMessage != nil },
			set: { if !$0 { model.errorMessage = nil } }
		)) {
			Button("OK", role: .cancel) {}
		} message: {
			Text(model.errorMessage ?? "")
		}
	}
}

/** Search field, the filtered list, and the custom-scheme field on the URL Schemes tab. */
@MainActor
private struct SidebarView: View {
	@EnvironmentObject private var model: AppModel
	@State private var newScheme = ""

	var body: some View {
		VStack(spacing: 8) {
			SearchField(text: $model.query, prompt: "Name, identifier or .ext", onMove: model.moveSelection)
				.padding([.horizontal, .top], 10)

			if model.category == .types {
				Picker("Group By", selection: $model.typeGrouping) {
					ForEach(TypeGrouping.allCases) { Text($0.rawValue).tag($0) }
				}
				.pickerStyle(.segmented)
				.labelsHidden()
				.padding(.horizontal, 10)
				.help("Group file types by kind or by the application that opens them")
			}

			if model.isLoading {
				ProgressView("Loading…")
					.controlSize(.small)
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			} else if model.sections.allSatisfy({ $0.entries.isEmpty }) {
				Text(model.query.isEmpty ? "Nothing Here" : "No Results")
					.foregroundStyle(.secondary)
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			} else {
				EntryList(model: model)
			}

			if model.category == .schemes {
				HStack(spacing: 6) {
					TextField("New scheme", text: $newScheme)
						.textFieldStyle(.roundedBorder)
						.onSubmit { addScheme() }
					Button("Add") { addScheme() }
						.disabled(newScheme.trimmingCharacters(in: .whitespaces).isEmpty)
				}
				.padding([.horizontal, .bottom], 10)
			}
		}
	}

	private func addScheme() {
		model.addScheme(newScheme)
		newScheme = ""
	}
}
