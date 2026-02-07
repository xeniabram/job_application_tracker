//
//  LocationSearchField.swift
//  cv-tracker
//
//  Created by Ksenia Pravdina on 07/02/2026.
//
import SwiftUI
import SwiftData
import MapKit
import Combine
import EventKit

// MARK: - Location Search Field
struct LocationSearchField: View {
    @Binding var location: String
    var onSave: (() -> Void)? = nil
    var autoFocus: Bool = true
    @StateObject private var searchCompleter = LocationSearchCompleter()
    @State private var selectedIndex: Int = -1
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Location", text: $location, prompt: Text("Search for a location..."))
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onChange(of: location) { _, newValue in
                    searchCompleter.searchQuery = newValue
                }
            
            if !searchCompleter.results.isEmpty {
                VStack {
                    ForEach(searchCompleter.results, id: \.self) { result in
                        Button {
                            location = "\(result.title), \(result.subtitle)"
                            searchCompleter.results = []
                            onSave?()
                        } label: {
                            VStack(alignment: .leading) {
                                Text(result.title).font(.body)
                                Text(result.subtitle).font(.caption).foregroundStyle(.secondary)
                            }.padding(4)
                        }.buttonStyle(.plain)
                        Divider()
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)
            }
        }
    }
}

// MARK: - Location Search Completer Helper
class LocationSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()
    var searchQuery: String = "" {
        didSet { if searchQuery.count > 2 { completer.queryFragment = searchQuery } else { results = [] } }
    }
    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) { results = completer.results }
}
