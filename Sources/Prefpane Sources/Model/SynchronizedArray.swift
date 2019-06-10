//
//  SynchronizedArray.swift
//  ZamzamKit
//  http://basememara.com/creating-thread-safe-arrays-in-swift/
//
//  Created by Basem Emara on 2/27/17.
//  Copyright © 2017 Zamzam Inc. All rights reserved.
//
//

import Foundation

/// A thread-safe array.
public class SynchronizedArray<Element> {
	private let queue = DispatchQueue(label: "\(DispatchQueue.labelPrefix).SynchronizedArray", qos: .utility, attributes: .concurrent)
	private var array = [Element]()
	
	public init() { }
	
	public convenience init(_ array: [Element]) {
		self.init()
		self.array = array
	}
}

// MARK: - Properties

public extension SynchronizedArray {
	/// Extract the inner array.
	var innerArray: [Element] { return self.array }
	
	/// The first element of the collection.
	var first: Element? {
		var result: Element?
		queue.sync { result = self.array.first }
		return result
	}
	
	/// The last element of the collection.
	var last: Element? {
		var result: Element?
		queue.sync { result = self.array.last }
		return result
	}
	
	/// The number of elements in the array.
	var count: Int {
		var result = 0
		queue.sync { result = self.array.count }
		return result
	}
	
	/// A Boolean value indicating whether the collection is empty.
	var isEmpty: Bool {
		var result = false
		queue.sync { result = self.array.isEmpty }
		return result
	}
	
	/// A textual representation of the array and its elements.
	var description: String {
		var result = ""
		queue.sync { result = self.array.description }
		return result
	}
}

// MARK: - Immutable

public extension SynchronizedArray {
	
	/// Returns the first element of the sequence that satisfies the given predicate.
	///
	/// - Parameter predicate: A closure that takes an element of the sequence as its argument and returns a Boolean value indicating whether the element is a match.
	/// - Returns: The first element of the sequence that satisfies predicate, or nil if there is no element that satisfies predicate.
	func first(where predicate: (Element) -> Bool) -> Element? {
		var result: Element?
		queue.sync { result = self.array.first(where: predicate) }
		return result
	}
	
	/// Returns the last element of the sequence that satisfies the given predicate.
	///
	/// - Parameter predicate: A closure that takes an element of the sequence as its argument and returns a Boolean value indicating whether the element is a match.
	/// - Returns: The last element of the sequence that satisfies predicate, or nil if there is no element that satisfies predicate.
	func last(where predicate: (Element) -> Bool) -> Element? {
		var result: Element?
		queue.sync { result = self.array.last(where: predicate) }
		return result
	}
	
	/// Returns an array containing, in order, the elements of the sequence that satisfy the given predicate.
	///
	/// - Parameter isIncluded: A closure that takes an element of the sequence as its argument and returns a Boolean value indicating whether the element should be included in the returned array.
	/// - Returns: An array of the elements that includeElement allowed.
	func filter(_ isIncluded: @escaping (Element) -> Bool) -> SynchronizedArray {
		var result: SynchronizedArray?
		queue.sync { result = SynchronizedArray(self.array.filter(isIncluded)) }
		return result ?? self
	}
	
	/// Returns the first index in which an element of the collection satisfies the given predicate.
	///
	/// - Parameter predicate: A closure that takes an element as its argument and returns a Boolean value that indicates whether the passed element represents a match.
	/// - Returns: The index of the first element for which predicate returns true. If no elements in the collection satisfy the given predicate, returns nil.
	func firstIndex(where predicate: (Element) -> Bool) -> Int? {
		var result: Int?
		queue.sync { result = self.array.firstIndex(where: predicate) }
		return result
	}
	
	/// Returns the elements of the collection, sorted using the given predicate as the comparison between elements.
	///
	/// - Parameter areInIncreasingOrder: A predicate that returns true if its first argument should be ordered before its second argument; otherwise, false.
	/// - Returns: A sorted array of the collection’s elements.
	func sorted(by areInIncreasingOrder: (Element, Element) -> Bool) -> SynchronizedArray {
		var result: SynchronizedArray?
		queue.sync { result = SynchronizedArray(self.array.sorted(by: areInIncreasingOrder)) }
		return result ?? self
	}
	
	/// Returns an array containing the results of mapping the given closure over the sequence’s elements.
	///
	/// - Parameter transform: A closure that accepts an element of this sequence as its argument and returns an optional value.
	/// - Returns: An array of the non-nil results of calling transform with each element of the sequence.
	func map<ElementOfResult>(_ transform: @escaping (Element) -> ElementOfResult) -> [ElementOfResult] {
		var result = [ElementOfResult]()
		queue.sync { result = self.array.map(transform) }
		return result
	}
	
	/// Returns an array containing the non-nil results of calling the given transformation with each element of this sequence.
	///
	/// - Parameter transform: A closure that accepts an element of this sequence as its argument and returns an optional value.
	/// - Returns: An array of the non-nil results of calling transform with each element of the sequence.
	func compactMap<ElementOfResult>(_ transform: (Element) -> ElementOfResult?) -> [ElementOfResult] {
		var result = [ElementOfResult]()
		queue.sync { result = self.array.compactMap(transform) }
		return result
	}
	
	/// Returns the result of combining the elements of the sequence using the given closure.
	///
	/// - Parameters:
	///   - initialResult: The value to use as the initial accumulating value. initialResult is passed to nextPartialResult the first time the closure is executed.
	///   - nextPartialResult: A closure that combines an accumulating value and an element of the sequence into a new accumulating value, to be used in the next call of the nextPartialResult closure or returned to the caller.
	/// - Returns: The final accumulated value. If the sequence has no elements, the result is initialResult.
	func reduce<ElementOfResult>(_ initialResult: ElementOfResult, _ nextPartialResult: @escaping (ElementOfResult, Element) -> ElementOfResult) -> ElementOfResult {
		var result: ElementOfResult?
		queue.sync { result = self.array.reduce(initialResult, nextPartialResult) }
		return result ?? initialResult
	}
	
	/// Returns the result of combining the elements of the sequence using the given closure.
	///
	/// - Parameters:
	///   - initialResult: The value to use as the initial accumulating value.
	///   - updateAccumulatingResult: A closure that updates the accumulating value with an element of the sequence.
	/// - Returns: The final accumulated value. If the sequence has no elements, the result is initialResult.
	func reduce<ElementOfResult>(into initialResult: ElementOfResult, _ updateAccumulatingResult: @escaping (inout ElementOfResult, Element) -> Void) -> ElementOfResult {
		var result: ElementOfResult?
		queue.sync { result = self.array.reduce(into: initialResult, updateAccumulatingResult) }
		return result ?? initialResult
	}
	
	/// Calls the given closure on each element in the sequence in the same order as a for-in loop.
	///
	/// - Parameter body: A closure that takes an element of the sequence as a parameter.
	func forEach(_ body: (Element) -> Void) {
		queue.sync { self.array.forEach(body) }
	}
	
	/// Returns a Boolean value indicating whether the sequence contains an element that satisfies the given predicate.
	///
	/// - Parameter predicate: A closure that takes an element of the sequence as its argument and returns a Boolean value that indicates whether the passed element represents a match.
	/// - Returns: true if the sequence contains an element that satisfies predicate; otherwise, false.
	func contains(where predicate: (Element) -> Bool) -> Bool {
		var result = false
		queue.sync { result = self.array.contains(where: predicate) }
		return result
	}
	
	/// Returns a Boolean value indicating whether every element of a sequence satisfies a given predicate.
	///
	/// - Parameter predicate: A closure that takes an element of the sequence as its argument and returns a Boolean value that indicates whether the passed element satisfies a condition.
	/// - Returns: true if the sequence contains only elements that satisfy predicate; otherwise, false.
	func allSatisfy(_ predicate: (Element) -> Bool) -> Bool {
		var result = false
		queue.sync { result = self.array.allSatisfy(predicate) }
		return result
	}
}

// MARK: - Mutable

public extension SynchronizedArray {
	
	/// Adds a new element at the end of the array.
	///
	/// The task is performed asynchronously due to thread-locking management.
	///
	/// - Parameters:
	///   - element: The element to append to the array.
	///   - completion: The block to execute when completed.
	func append(_ element: Element, completion: (() -> Void)? = nil) {
		queue.async(flags: .barrier) {
			self.array.append(element)
			DispatchQueue.main.async { completion?() }
		}
	}
	
	/// Adds new elements at the end of the array.
	///
	/// The task is performed asynchronously due to thread-locking management.
	///
	/// - Parameters:
	///   - element: The elements to append to the array.
	///   - completion: The block to execute when completed.
	func append(_ elements: [Element], completion: (() -> Void)? = nil) {
		queue.async(flags: .barrier) {
			self.array += elements
			DispatchQueue.main.async { completion?() }
		}
	}
	
	/// Inserts a new element at the specified position.
	///
	/// The task is performed asynchronously due to thread-locking management.
	///
	/// - Parameters:
	///   - element: The new element to insert into the array.
	///   - index: The position at which to insert the new element.
	///   - completion: The block to execute when completed.
	func insert(_ element: Element, at index: Int, completion: (() -> Void)? = nil) {
		queue.async(flags: .barrier) {
			self.array.insert(element, at: index)
			DispatchQueue.main.async { completion?() }
		}
	}
	
	/// Removes and returns the first element of the collection.
	///
	/// The collection must not be empty.
	/// The task is performed asynchronously due to thread-locking management.
	///
	/// - Parameter completion: The handler with the removed element.
	func removeFirst(completion: ((Element) -> Void)? = nil) {
		queue.async(flags: .barrier) {
			let element = self.array.removeFirst()
			DispatchQueue.main.async { completion?(element) }
		}
	}
	
	/// Removes the specified number of elements from the beginning of the collection.
	///
	/// The task is performed asynchronously due to thread-locking management.
	///
	/// - Parameters:
	///   - k: The number of elements to remove from the collection.
	///   - completion: The block to execute when remove completed.
	func removeFirst(_ k: Int, completion: (() -> Void)? = nil) {
		queue.async(flags: .barrier) {
			defer { DispatchQueue.main.async { completion?() } }
			guard 0...self.array.count ~= k else { return }
			self.array.removeFirst(k)
		}
	}
	
	/// Removes and returns the last element of the collection.
	///
	/// The collection must not be empty.
	/// The task is performed asynchronously due to thread-locking management.
	///
	/// - Parameter completion: The handler with the removed element.
	func removeLast(completion: ((Element) -> Void)? = nil) {
		queue.async(flags: .barrier) {
			let element = self.array.removeLast()
			DispatchQueue.main.async { completion?(element) }
		}
	}
	
	/// Removes the specified number of elements from the end of the collection.
	///
	/// The task is performed asynchronously due to thread-locking management.
	///
	/// - Parameters:
	///   - k: The number of elements to remove from the collection.
	///   - completion: The block to execute when remove completed.
	func removeLast(_ k: Int, completion: (() -> Void)? = nil) {
		queue.async(flags: .barrier) {
			defer { DispatchQueue.main.async { completion?() } }
			guard 0...self.array.count ~= k else { return }
			self.array.removeLast(k)
		}
	}
	
	/// Removes and returns the element at the specified position.
	///
	/// The task is performed asynchronously due to thread-locking management.
	///
	/// - Parameters:
	///   - index: The position of the element to remove.
	///   - completion: The handler with the removed element.
	func remove(at index: Int, completion: ((Element) -> Void)? = nil) {
		queue.async(flags: .barrier) {
			let element = self.array.remove(at: index)
			DispatchQueue.main.async { completion?(element) }
		}
	}
	
	/// Removes and returns the elements that meet the criteria.
	///
	/// The task is performed asynchronously due to thread-locking management.
	///
	/// - Parameters:
	///   - predicate: A closure that takes an element of the sequence as its argument and returns a Boolean value indicating whether the element is a match.
	///   - completion: The handler with the removed elements.
	func remove(where predicate: @escaping (Element) -> Bool, completion: (([Element]) -> Void)? = nil) {
		queue.async(flags: .barrier) {
			var elements = [Element]()
			
			while let index = self.array.firstIndex(where: predicate) {
				elements.append(self.array.remove(at: index))
			}
			
			DispatchQueue.main.async { completion?(elements) }
		}
	}
	
	/// Removes all elements from the array.
	///
	/// The task is performed asynchronously due to thread-locking management.
	///
	/// - Parameter completion: The handler with the removed elements.
	func removeAll(completion: (([Element]) -> Void)? = nil) {
		queue.async(flags: .barrier) {
			let elements = self.array
			self.array.removeAll()
			DispatchQueue.main.async { completion?(elements) }
		}
	}
}

public extension SynchronizedArray {
	
	/// Accesses the element at the specified position if it exists.
	///
	/// - Parameter index: The position of the element to access.
	/// - Returns: optional element if it exists.
	subscript(index: Int) -> Element? {
		get {
			var result: Element?
			queue.sync { result = self.array[safe: index] }
			return result
		}
		
		set {
			guard let newValue = newValue else { return }
			
			queue.async(flags: .barrier) {
				self.array[index] = newValue
			}
		}
	}
}

// MARK: - Equatable

public extension SynchronizedArray where Element: Equatable {
	
	/// Returns a Boolean value indicating whether the sequence contains the given element.
	///
	/// - Parameter element: The element to find in the sequence.
	/// - Returns: true if the element was found in the sequence; otherwise, false.
	func contains(_ element: Element) -> Bool {
		var result = false
		queue.sync { result = self.array.contains(element) }
		return result
	}
	
	/// Removes the specified element.
	///
	/// The task is performed asynchronously due to thread-locking management.
	///
	/// - Parameter element: An element to search for in the collection.
	func remove(_ element: Element, completion: (() -> Void)? = nil) {
		queue.async(flags: .barrier) {
			self.array.remove(element)
			DispatchQueue.main.async { completion?() }
		}
	}
	
	/// Removes the specified element.
	///
	/// The task is performed asynchronously due to thread-locking management.
	///
	/// - Parameters:
	///   - left: The collection to remove from.
	///   - right: An element to search for in the collection.
	static func -= (left: inout SynchronizedArray, right: Element) {
		left.remove(right)
	}
}

// MARK: - Infix operators

public extension SynchronizedArray {
	
	/// Adds a new element at the end of the array.
	///
	/// The task is performed asynchronously due to thread-locking management.
	///
	/// - Parameters:
	///   - left: The collection to append to.
	///   - right: The element to append to the array.
	static func += (left: inout SynchronizedArray, right: Element) {
		left.append(right)
	}
	
	/// Adds new elements at the end of the array.
	///
	/// The task is performed asynchronously due to thread-locking management.
	///
	/// - Parameters:
	///   - left: The collection to append to.
	///   - right: The elements to append to the array.
	static func += (left: inout SynchronizedArray, right: [Element]) {
		left.append(right)
	}
}

private extension SynchronizedArray {
	//swiftlint:disable file_length
}
