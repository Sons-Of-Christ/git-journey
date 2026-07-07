package com.orangehrm.tests;

import io.github.bonigarcia.wdm.WebDriverManager;
import org.openqa.selenium.By;
import org.openqa.selenium.WebDriver;
import org.openqa.selenium.WebElement;
import org.openqa.selenium.chrome.ChromeDriver;
import org.openqa.selenium.chrome.ChromeOptions;
import org.openqa.selenium.support.ui.ExpectedConditions;
import org.openqa.selenium.support.ui.WebDriverWait;
import org.testng.Assert;
import org.testng.annotations.AfterMethod;
import org.testng.annotations.BeforeClass;
import org.testng.annotations.BeforeMethod;
import org.testng.annotations.Test;

import java.time.Duration;

/**
 * Smoke Test Verification Script for OrangeHRM Test Environment Setup.
 * Verified by Team B.
 */
public class OrangeHRMSmokeTest {

    private WebDriver driver;
    private WebDriverWait wait;
    private final String BASE_URL = "[https://opensource-demo.orangehrmlive.com](https://opensource-demo.orangehrmlive.com)";

    @BeforeClass
    public static void setupSuite() {
        // Automatically configures Chrome binary driver matching local browser version
        WebDriverManager.chromedriver().setup();
    }

    @BeforeMethod
    public void setUp() {
        ChromeOptions options = new ChromeOptions();
        options.addArguments("--start-maximized");
        options.addArguments("--disable-notifications");
        
        driver = new ChromeDriver(options);
        wait = new WebDriverWait(driver, Duration.ofSeconds(10));
        driver.get(BASE_URL);
    }

    @Test(priority = 1, description = "Verify OrangeHRM login landing page is accessible")
    public void testLoginPageLoads() {
        String pageTitle = driver.getTitle();
        Assert.assertEquals(pageTitle, "OrangeHRM", "Landing Page title verification failed.");
        
        WebElement usernameInput = wait.until(ExpectedConditions.visibilityOfElementLocated(By.name("username")));
        Assert.assertTrue(usernameInput.isDisplayed(), "Username field not visible on landing page.");
    }

    @Test(priority = 2, description = "Verify successful authentication using valid credentials")
    public void testValidLoginAuthentication() {
        // Input valid credentials
        WebElement usernameField = wait.until(ExpectedConditions.visibilityOfElementLocated(By.name("username")));
        WebElement passwordField = driver.findElement(By.name("password"));
        
        usernameField.sendKeys("Admin");
        passwordField.sendKeys("admin123");
        
        WebElement loginBtn = driver.findElement(By.xpath("//button[@type='submit']"));
        loginBtn.click();
        
        // Wait for system redirect and validate target dashboard URL path
        wait.until(ExpectedConditions.urlContains("/dashboard/index"));
        String currentUrl = driver.getCurrentUrl();
        Assert.assertTrue(currentUrl.contains("/dashboard/index"), "Login authentication failed to redirect to Dashboard.");
    }

    @Test(priority = 3, description = "Verify authentication failure on invalid credentials submittal")
    public void testInvalidLoginAuthentication() {
        WebElement usernameField = wait.until(ExpectedConditions.visibilityOfElementLocated(By.name("username")));
        WebElement passwordField = driver.findElement(By.name("password"));
        
        usernameField.sendKeys("Admin");
        passwordField.sendKeys("WrongPassword123");
        
        WebElement loginBtn = driver.findElement(By.xpath("//button[@type='submit']"));
        loginBtn.click();
        
        // Wait for validation warning banner to load in UI
        WebElement errorAlert = wait.until(ExpectedConditions.visibilityOfElementLocated(
                By.xpath("//p[contains(@class, 'oxd-alert-content-text')]")
        ));
        
        String alertText = errorAlert.getText();
        Assert.assertEquals(alertText, "Invalid credentials", "Validation error text does not match expected result.");
    }

    @AfterMethod
    public void tearDown() {
        if (driver != null) {
            driver.quit();
        }
    }
}