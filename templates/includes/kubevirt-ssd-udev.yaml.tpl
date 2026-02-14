apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  name: 99-master-ssd-rotational
  labels:
    machineconfiguration.openshift.io/role: master
spec:
  config:
    ignition:
      version: 3.4.0
    storage:
      files:
        - path: /etc/udev/rules.d/99-ssd-rotational.rules
          mode: 0644
          overwrite: true
          contents:
            source: data:text/plain;charset=utf-8;base64,QUNUSU9OPT0iYWRkfGNoYW5nZSIsIEtFUk5FTD09InNkW2Etel0iLCBTVUJTWVNURU09PSJibG9jayIsICBBVFRSe3F1ZXVlL3JvdGF0aW9uYWx9PSIwIgpBQ1RJT049PSJhZGR8Y2hhbmdlIiwgS0VSTkVMPT0idmRbYS16XSIsIFNVQlNZU1RFTT09ImJsb2NrIiwgIEFUVFJ7cXVldWUvcm90YXRpb25hbH09IjAiCg==
