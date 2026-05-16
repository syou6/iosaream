import Foundation
import SwiftData

public enum SchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version = .init(1, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            AlarmEntity.self,
            MissionTemplateEntity.self,
            MissionRunEntity.self,
            ProfileEntity.self
        ]
    }
}

public enum AppSchemaMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    public static var stages: [MigrationStage] {
        []
    }
}
