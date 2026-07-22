
//
//  MemoryCard.swift
//  PetApp
//
//  A single row in the Archive list: photo thumbnail (if any), title, date,
//  and a favourite indicator.
//
 
import SwiftUI
 
struct MemoryCard: View {
    let memory: Memory
 
    var body: some View {
        HStack(spacing: Spacing.md) {
            thumbnail
 
            VStack(alignment: .leading, spacing: 4) {
                Text(memory.title.isEmpty ? "Untitled memory" : memory.title)
                    .font(.headline)
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(1)
                Text(memory.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
            }
 
            Spacer()
 
            if memory.isFavourite {
                Image(systemName: "star.fill")
                    .foregroundStyle(AppColor.ninja)
            }
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppColor.snow))
        .accessibilityElement(children: .combine)
    }
 
    @ViewBuilder
    private var thumbnail: some View {
        if let photoFileName = memory.photoFileName,
           let uiImage = UIImage(contentsOfFile: FileStorageService.photoURL(for: photoFileName).path) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColor.screenBackground)
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "text.book.closed")
                        .foregroundStyle(AppColor.textSecondary)
                )
        }
    }
}
