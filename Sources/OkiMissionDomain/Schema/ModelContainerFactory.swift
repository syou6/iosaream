import Foundation
import SwiftData

public enum ModelContainerFactory {
    public static func live() throws -> ModelContainer {
        let schema = Schema(SchemaV1.models)
        let configuration = ModelConfiguration(schema: schema)
        return try ModelContainer(
            for: schema,
            migrationPlan: AppSchemaMigrationPlan.self,
            configurations: configuration
        )
    }

    public static func inMemory() throws -> ModelContainer {
        let schema = Schema(SchemaV1.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: configuration)
    }
}
