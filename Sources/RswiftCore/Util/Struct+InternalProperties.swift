//
//  Struct+InternalProperties.swift
//  R.swift
//
//  Created by Mathijs Kadijk on 06-10-16.
//  Copyright © 2016 Mathijs Kadijk. All rights reserved.
//

import Foundation

extension Struct {
  func addingInternalProperties(forResourceBundleIdentifier bundleIdentifier: String?) -> Struct {

    let bundleLet: Let
    var bundleFunction: Function?

    if let bundleIdentifier = bundleIdentifier {
        bundleLet = Let(
            comments: [],
            accessModifier: .internalLevel,
            isStatic: true,
            name: "hostingBundle",
            typeDefinition: .inferred(Type._Bundle),
            value: "makeHostingBundle()"
        )

        bundleFunction = Function(
          availables: [],
          comments: [],
          accessModifier: .filePrivate,
          isStatic: true,
          name: "makeHostingBundle",
          generics: nil,
          parameters: [],
          doesThrow: false,
          returnType: Type._Bundle,
          body: """
            guard let path = Bundle(for: R.Class.self).path(forResource: "\(bundleIdentifier)", ofType: "bundle") else {
              fatalError("Path for \(bundleIdentifier) bundle not found!")
            }
            guard let bundle = Bundle(path: path) else {
              fatalError("Unable to instantiate \(bundleIdentifier) bundle!")
            }

            return bundle
            """,
          os: []
        )
    } else {
        bundleLet = Let(
            comments: [],
            accessModifier: .internalLevel,
            isStatic: true,
            name: "hostingBundle",
            typeDefinition: .inferred(Type._Bundle),
            value: "Bundle(for: R.Class.self)"
        )
    }

    let internalProperties = [
      bundleLet,
      Let(
        comments: [],
        accessModifier: .filePrivate,
        isStatic: true,
        name: "applicationLocale",
        typeDefinition: .inferred(Type._Locale),
        value: "hostingBundle.preferredLocalizations.first.flatMap { Locale(identifier: $0) } ?? Locale.current")
    ]

    let internalClasses = [
      Class(accessModifier: .filePrivate, type: Type(module: .host, name: "Class"))
    ]

    let internalFunctions = [
      bundleFunction,
      Function(
        availables: [],
        comments: ["Load string from Info.plist file"],
        accessModifier: .filePrivate,
        isStatic: true,
        name: "infoPlistString",
        generics: nil,
        parameters: [
          .init(name: "path", type: Type._Array.withGenericArgs([Type._String])),
          .init(name: "key", type: Type._String)
        ],
        doesThrow: false,
        returnType: Type._String.asOptional(),
        body: """
          var dict = hostingBundle.infoDictionary
          for step in path {
            guard let obj = dict?[step] as? [String: Any] else { return nil }
            dict = obj
          }
          return dict?[key] as? String
          """,
        os: []
      ),
      Function(
        availables: [],
        comments: ["Find first language and bundle for which the table exists"],
        accessModifier: .filePrivate,
        isStatic: true,
        name: "localeBundle",
        generics: nil,
        parameters: [
          .init(name: "tableName", type: Type._String),
          .init(name: "preferredLanguages", type: Type._Array.withGenericArgs([Type._String]))
        ],
        doesThrow: false,
        returnType: Type._Tuple.withGenericArgs([Type._Locale, Type._Bundle]).asOptional(),
        body: """
          // Filter preferredLanguages to localizations, use first locale
          var languages = preferredLanguages
            .map { Locale(identifier: $0) }
            .prefix(1)
            .flatMap { locale -> [String] in
              if hostingBundle.localizations.contains(locale.identifier) {
                if let language = locale.languageCode, hostingBundle.localizations.contains(language) {
                  return [locale.identifier, language]
                } else {
                  return [locale.identifier]
                }
              } else if let language = locale.languageCode, hostingBundle.localizations.contains(language) {
                return [language]
              } else {
                return []
              }
            }

          // If there's no languages, use development language as backstop
          if languages.isEmpty {
            if let developmentLocalization = hostingBundle.developmentLocalization {
              languages = [developmentLocalization]
            }
          } else {
            // Insert Base as second item (between locale identifier and languageCode)
            languages.insert("Base", at: 1)

            // Add development language as backstop
            if let developmentLocalization = hostingBundle.developmentLocalization {
              languages.append(developmentLocalization)
            }
          }

          // Find first language for which table exists
          // Note: key might not exist in chosen language (in that case, key will be shown)
          for language in languages {
            if let lproj = hostingBundle.url(forResource: language, withExtension: "lproj"),
               let lbundle = Bundle(url: lproj)
            {
              let strings = lbundle.url(forResource: tableName, withExtension: "strings")
              let stringsdict = lbundle.url(forResource: tableName, withExtension: "stringsdict")

              if strings != nil || stringsdict != nil {
                return (Locale(identifier: language), lbundle)
              }
            }
          }

          // If table is available in main bundle, don't look for localized resources
          let strings = hostingBundle.url(forResource: tableName, withExtension: "strings", subdirectory: nil, localization: nil)
          let stringsdict = hostingBundle.url(forResource: tableName, withExtension: "stringsdict", subdirectory: nil, localization: nil)

          if strings != nil || stringsdict != nil {
            return (applicationLocale, hostingBundle)
          }

          // If table is not found for requested languages, key will be shown
          return nil
          """,
        os: []
      )
        ].compactMap { $0 }

    var externalStruct = self
    externalStruct.properties.append(contentsOf: internalProperties)
    externalStruct.functions.append(contentsOf: internalFunctions)
    externalStruct.classes.append(contentsOf: internalClasses)

    return externalStruct
  }
}
