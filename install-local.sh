#!/bin/bash
rm helm_output.log

# Set the namespace
NAMESPACE=stord

# Install or upgrade the PostgreSQL Helm chart
echo "Installing postgres database, hang tight..."

helm upgrade --install sre-db oci://registry-1.docker.io/bitnamicharts/postgresql \
  --create-namespace \
  --namespace $NAMESPACE \
  --set auth.database=sre-technical-challenge \
  --set auth.postgresPassword=password > helm_output.log 2>&1

echo "Successfully installed postgres."

# Wait for the PostgreSQL pod to be in a Ready state
echo "Waiting for PostgreSQL pod to be ready..."
kubectl wait --namespace $NAMESPACE --for=condition=ready pod -l app.kubernetes.io/name=postgresql --timeout=300s

# Deploy the application
helm upgrade --install sre-app . \
  --debug \
  --namespace $NAMESPACE \
  --values values.yaml > helm_output.log 2>&1

# Wait for the application pod to be in a Ready state
echo "Waiting for application pod to be ready..."
kubectl wait --namespace $NAMESPACE --for=condition=ready pod -l app=sre-app --timeout=300s

# Port-forward to access the application (as needed for validation/testing)
kubectl port-forward svc/sre-app-sre-technical-challenge 8080:80 --namespace $NAMESPACE &
APP_PF_PID=$!
echo "Port forwarding setup for application"

# Sleep for a few seconds to ensure the port-forward is established
sleep 2

# Retrieve the PostgreSQL pod name
POSTGRES_POD=$(kubectl get pod -l app.kubernetes.io/name=postgresql -n $NAMESPACE -o jsonpath="{.items[0].metadata.name}")

# Validate database connection and migrations by execing into the PostgreSQL pod
echo "Validating database connectivity and migrations..."
kubectl exec -n $NAMESPACE $POSTGRES_POD -- bash -c "PGPASSWORD='password' psql -U postgres -d sre-technical-challenge -c '\dt'"


# Validation command to check if the application is up and running
echo "Validating application readiness..."
curl http://localhost:8080/_health

# Optionally, keep the script running if you want to manually test the app
read -p "App available at http://localhost:8080/todos - press any key to terminate port forwarding..."
kill $APP_PF_PID

echo "Deployment and validation process completed."
