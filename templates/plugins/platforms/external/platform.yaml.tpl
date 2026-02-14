  external:
    platformName: {{ platformPlugin.platformName | default("oci") }}
    cloudControllerManager: {{ platformPlugin.cloudControllerManager | default("External") }}
