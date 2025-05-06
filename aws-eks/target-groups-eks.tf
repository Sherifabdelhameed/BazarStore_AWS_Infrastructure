# This file will be used for dynamic target group attachments
# Managed by AWS Load Balancer Controller via Kubernetes Ingress resources

# Example Kubernetes Ingress manifest (apply with kubectl):
/*
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: sample-app-ingress
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: instance
spec:
  rules:
    - http:
        paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: sample-app-service
              port:
                number: 80
*/