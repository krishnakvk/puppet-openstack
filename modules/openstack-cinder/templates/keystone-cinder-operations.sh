#!/bin/sh
#
# Create cinder user and service and endpoint.

keystone_host="<%=  @KEYSTONE_HOST %>"
admin_port="<%= @KEYSTONE_ADMIN_PORT %>"
admin_token="<%= @ADMIN_TOKEN %>"
region="<%= @region %>"

admin_tenant="<%=  @admin_tenant %>"
admin_user="<%= @admin_user %>"
admin_user_pass="<%= @admin_user_pass %>"
cinder_user_pass="<%= @CINDER_USER_PASSWORD %>"

export OS_AUTH_URL=http://${keystone_host}:${admin_port}/v2.0
export OS_PROJECT_DOMAIN_ID=default
export OS_USER_DOMAIN_ID=default
export OS_PROJECT_NAME=admin
export OS_TENANT_NAME=${admin_tenant}
export OS_USERNAME=${admin_user}
export OS_PASSWORD=${admin_user_pass}
export OS_AUTH_URL=http://${keystone_host}:${admin_port}/v3


# Create the Cinder user.
get_user_id () {
        openstack user list | awk -F'|' '{print $2,$3}' | awk -vuser_name="$1" ' $2 == user_name  {print $1} '       
}

user_id=$(get_user_id cinder)

if [ "$user_id" ]; then
        echo "Found existing user id: $user_id"
else
        # Create the Cinder user
        openstack user create cinder --password="$cinder_user_pass" --email="cinder@example.com"

        # Add the admin role to Cinder user
        openstack role add --project service --user cinder admin
        user_id=$(get_user_id cinder)

        if [ "$user_id" ]; then
                echo "Created new User: $user_id"
        else
                echo "ERROR: Failed to create User."
                exit 1
        fi
fi

#Create a Cinder service
get_service_id () {
        openstack service list | awk -F'|' '{print $2,$3,$4}' | awk -vservice_name="$1" -vservice_type="$2" '
                 $2 == service_name && $3 == service_type {print $1} '
}

service_id_v1=$(get_service_id cinder volume)

if [ "$service_id_v1" ]; then
        echo "Found existing service id: $service_id_v1"
else
        # Create the Service
        openstack service create --name cinder  --description "OpenStack Block Storage" volume
        service_id_v1=$(get_service_id cinder volume)

        if [ "$service_id_v1" ]; then
                echo "Created new service id: $service_id_v1"
        else
                echo "ERROR: Failed to create service."
                exit 1
        fi
fi

#Create a Cinderv2 service
service_id_v2=$(get_service_id cinderv2 volumev2)

if [ "$service_id_v2" ]; then
        echo "Found existing service id: $service_id_v2"
else
        # Creat the service
        openstack service create --name cinderv2  --description "OpenStack Block Storage" volumev2

        service_id_v2=$(get_service_id cinderv2 volumev2)

        if [ "$service_id_v2" ]; then
                echo "Created new service id: $service_id_v2"
        else
                echo "ERROR: Failed to create service."
                exit 1
        fi
fi

# Create the Cinder Service API endpoints
get_keystone_endpoint () {
        openstack endpoint list |  awk -F'|' '{print $2,$3,$4,$5}' | awk -vservice_name="$1" -vservice_type="$2" '
               $3 == service_name && $4 == service_type {print $1} '
}

endpoint_id_v1=$(get_keystone_endpoint cinder volume)
endpoint_id_v2=$(get_keystone_endpoint cinderv2 volumev2 )

if [ "$endpoint_id_v1" ]; then
        echo "Found existing endpoint: $endpoint_id_v1"
else
        openstack endpoint create  \
                --publicurl http://"$keystone_host":8776/v2/%\(tenant_id\)s \
                --internalurl http://"$keystone_host":8776/v2/%\(tenant_id\)s \
                --adminurl http://"$keystone_host":8776/v2/%\(tenant_id\)s \
                --region "$region" \
                volume
fi

if [ "$endpoint_id_v2" ]; then
        echo "Found existing endpoint: $endpoint_id_v2"
else
        openstack endpoint create \
                --publicurl http://"$keystone_host":8776/v2/%\(tenant_id\)s \
                --internalurl http://"$keystone_host":8776/v2/%\(tenant_id\)s \
                --adminurl http://"$keystone_host":8776/v2/%\(tenant_id\)s \
                --region "$region" \
                volumev2

fi
