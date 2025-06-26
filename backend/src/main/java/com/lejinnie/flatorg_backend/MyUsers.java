package com.lejinnie.flatorg_backend;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "users")
public class MyUsers {
    
    @Id
    @GeneratedValue()
    private String email;
    private String username;
    private int flat_id;

    MyUsers(String email, String username){
        this.email = email;
        this.username = username;
    }

    // GETTERS

    public String getEmail() {
        return email;
    }

    public String getUsername() {
        return username;
    }

    public int getFlat_id() {
        return flat_id;
    }


    // SETTERS
    public boolean setEmail(String email) {
        if(!(email.indexOf('@') < 0)) return false;

        this.email = email;
        return true;
    }

    public void setUsername(String username) {
        this.username = username;
    }

    public void setFlat_id(int flat_id) {

        // TODO: insert check for valid flat_id

        this.flat_id = flat_id;
    }
}
