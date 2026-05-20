// AppTheme.swift — Gardicol Connector
// Central color, surface, and spacing tokens for the calm high-tech UI.

import SwiftUI

public enum AppTheme {
    
    // MARK: - Surfaces
    public enum surface {
        /// Primary window background; deep graphite, never pure black.
        public static let base = Color(red: 0.08, green: 0.09, blue: 0.10)
        
        /// Sidebar cards, cluster panels, terminal chrome.
        public static let card = Color(red: 0.12, green: 0.13, blue: 0.15)
        
        /// Selected rows, panels, popovers.
        public static let elevated = Color(red: 0.16, green: 0.17, blue: 0.19)
    }
    
    // MARK: - Text
    public enum text {
        public static let primary = Color.primary
        public static let secondary = Color.secondary
        public static let muted = Color(white: 0.5)
    }
    
    // MARK: - Accents
    public enum accent {
        /// Transformative teal: Open actions, active tab, cluster highlight.
        public static let primary = Color(red: 0.0, green: 0.6, blue: 0.6)
        
        /// Soft cyan: Topology edges, metadata, active machine indicators.
        public static let secondary = Color(red: 0.2, green: 0.8, blue: 0.8)
        
        /// Digital lavender: Policy digestion, AI-like analysis, secondary insight.
        public static let info = Color(red: 0.6, green: 0.5, blue: 0.9)
    }
    
    // MARK: - Semantic
    public enum semantic {
        /// Muted emerald: Healthy, connected, passed validation.
        public static let success = Color(red: 0.2, green: 0.7, blue: 0.4)
        
        /// Soft amber: Partial data, pending sync, non-fatal warnings.
        public static let warning = Color(red: 0.9, green: 0.6, blue: 0.2)
        
        /// Calm crimson: Disconnected, failed validation, missing agent.
        public static let error = Color(red: 0.8, green: 0.3, blue: 0.3)
    }
}
