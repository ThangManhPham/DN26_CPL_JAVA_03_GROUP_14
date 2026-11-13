package com.ourspace;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.MigrationInfo;
import org.flywaydb.core.api.MigrationState;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.ResultSet;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest
@ActiveProfiles("test")
class OurSpaceApplicationTests {
    @Autowired Flyway flyway;
    @Autowired DataSource dataSource;

    @Test void contextLoadsWithRealMigrations() throws Exception {
        // Current highest migration version matches base (V6 couple events)
        assertThat(flyway.info().current()).isNotNull();
        assertThat(flyway.info().current().getVersion()).isNotNull();
        assertThat(flyway.info().current().getVersion().toString()).isEqualTo("6");
        assertThat(flyway.info().pending()).isEmpty();

        // Verify Flyway history specifically contains V5 (create_albums) with SUCCESS state
        // Null-safe for repeatable migrations (where info.getVersion() is null)
        MigrationInfo v5Info = Arrays.stream(flyway.info().applied())
                .filter(info -> info.getVersion() != null && "5".equals(info.getVersion().toString()))
                .findFirst()
                .orElse(null);

        assertThat(v5Info).isNotNull();
        assertThat(v5Info.getDescription()).isEqualTo("create albums");
        assertThat(v5Info.getState()).isEqualTo(MigrationState.SUCCESS);

        // Verify database metadata dynamically without hardcoding table case or schema
        try (Connection conn = dataSource.getConnection()) {
            DatabaseMetaData meta = conn.getMetaData();

            // Locate exact table names, catalogs, and schemas as recognized by the database
            // Key: lower-case table name -> Value: TableLocation (catalog, schema, exactTableName)
            record TableLocation(String catalog, String schema, String tableName) {}
            Map<String, TableLocation> discoveredTables = new HashMap<>();

            try (ResultSet rs = meta.getTables(null, null, "%", new String[]{"TABLE"})) {
                while (rs.next()) {
                    String cat = rs.getString("TABLE_CAT");
                    String schem = rs.getString("TABLE_SCHEM");
                    String tName = rs.getString("TABLE_NAME");
                    if (tName != null) {
                        discoveredTables.put(tName.toLowerCase(), new TableLocation(cat, schem, tName));
                    }
                }
            }

            assertThat(discoveredTables)
                    .containsKeys("albums", "album_photos", "couples", "photos", "users");

            // 1. Verify foreign keys in 'albums' table (couple_id -> couples, created_by -> users, cover_photo_id -> photos)
            TableLocation albumsLoc = discoveredTables.get("albums");
            Set<String> albumsReferencedTables = new HashSet<>();
            try (ResultSet rs = meta.getImportedKeys(albumsLoc.catalog(), albumsLoc.schema(), albumsLoc.tableName())) {
                while (rs.next()) {
                    String pkTable = rs.getString("PKTABLE_NAME");
                    if (pkTable != null) {
                        albumsReferencedTables.add(pkTable.toLowerCase());
                    }
                }
            }
            assertThat(albumsReferencedTables).contains("couples", "users");

            // 2. Verify foreign keys in 'album_photos' table (album_id -> albums, photo_id -> photos)
            TableLocation albumPhotosLoc = discoveredTables.get("album_photos");
            Set<String> albumPhotosReferencedTables = new HashSet<>();
            try (ResultSet rs = meta.getImportedKeys(albumPhotosLoc.catalog(), albumPhotosLoc.schema(), albumPhotosLoc.tableName())) {
                while (rs.next()) {
                    String pkTable = rs.getString("PKTABLE_NAME");
                    if (pkTable != null) {
                        albumPhotosReferencedTables.add(pkTable.toLowerCase());
                    }
                }
            }
            assertThat(albumPhotosReferencedTables).contains("albums", "photos");
        }
    }
}
